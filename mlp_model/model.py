#!/usr/bin/env python3
"""
2-layer MLP (PyTorch) for 60x60 binary images -> {circle, square, line}

Goal:
- Train float model
- Post-training quantize:
  * W1 int8  (64 x 3600)
  * b1 int32 (64,)
  * W2 int8  (3 x 64)
  * b2 int32 (3,)
- Choose activation requant SHIFT for a1:
  a1_int32 (after ReLU) -> a1_q int8 via:
    a1_q = clamp( ((a1 + (1<<(SHIFT-1))) >> SHIFT), 0..127 )
- Integer-only inference emulation and match rate vs float model argmax

Only deps: torch, numpy, standard library
"""

import argparse
import os
import math
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F


# -----------------------------
# Synthetic data generation
# -----------------------------

def _clip01(img: np.ndarray) -> np.ndarray:
    return (img > 0).astype(np.uint8)

def _add_salt_pepper(img: np.ndarray, p_flip: float, rng: np.random.Generator) -> np.ndarray:
    if p_flip <= 0.0:
        return img
    mask = rng.random(img.shape) < p_flip
    out = img.copy()
    out[mask] = 1 - out[mask]
    return out

def _add_dropout(img: np.ndarray, p_drop: float, rng: np.random.Generator) -> np.ndarray:
    # randomly erase some "on" pixels to mimic broken strokes
    if p_drop <= 0.0:
        return img
    mask = (rng.random(img.shape) < p_drop) & (img == 1)
    out = img.copy()
    out[mask] = 0
    return out

def gen_circle(size=60, rng=None,
               r_min=12, r_max=22,
               thickness_min=1, thickness_max=3,
               center_jitter=4,
               roughness=2.5) -> np.ndarray:
    """Imperfect ring-like circle with thickness + radius noise."""
    if rng is None:
        rng = np.random.default_rng()
    img = np.zeros((size, size), dtype=np.uint8)

    cx = size // 2 + rng.integers(-center_jitter, center_jitter + 1)
    cy = size // 2 + rng.integers(-center_jitter, center_jitter + 1)
    r0 = rng.integers(r_min, r_max + 1)
    t = rng.integers(thickness_min, thickness_max + 1)

    yy, xx = np.mgrid[0:size, 0:size]
    dx = xx - cx
    dy = yy - cy
    dist = np.sqrt(dx * dx + dy * dy)

    # radius noise: add smooth-ish noise by mixing a few random sinusoids
    # (keeps it "imperfect" without external libs)
    ang = np.arctan2(dy, dx)
    # random harmonics
    n1 = rng.uniform(-1.0, 1.0) * np.sin(3 * ang + rng.uniform(0, 2 * math.pi))
    n2 = rng.uniform(-1.0, 1.0) * np.sin(5 * ang + rng.uniform(0, 2 * math.pi))
    n3 = rng.uniform(-1.0, 1.0) * np.sin(7 * ang + rng.uniform(0, 2 * math.pi))
    rad_noise = roughness * (0.50 * n1 + 0.30 * n2 + 0.20 * n3)

    ring = np.abs(dist - (r0 + rad_noise)) <= t
    img[ring] = 1
    return img

def gen_square(size=60, rng=None,
               side_min=22, side_max=34,
               thickness_min=1, thickness_max=3,
               center_jitter=4,
               wobble=2,
               fill_prob=0.10) -> np.ndarray:
    """Imperfect square outline with ragged edges; sometimes partially filled."""
    if rng is None:
        rng = np.random.default_rng()
    img = np.zeros((size, size), dtype=np.uint8)

    cx = size // 2 + rng.integers(-center_jitter, center_jitter + 1)
    cy = size // 2 + rng.integers(-center_jitter, center_jitter + 1)
    side = int(rng.integers(side_min, side_max + 1))
    t = int(rng.integers(thickness_min, thickness_max + 1))

    half = side // 2
    x0 = max(0, cx - half)
    x1 = min(size - 1, cx + half)
    y0 = max(0, cy - half)
    y1 = min(size - 1, cy + half)

    # ragged outline by wobbling each edge a bit
    for x in range(x0, x1 + 1):
        y_top = y0 + int(rng.integers(-wobble, wobble + 1))
        y_bot = y1 + int(rng.integers(-wobble, wobble + 1))
        y_top = max(0, min(size - 1, y_top))
        y_bot = max(0, min(size - 1, y_bot))
        img[max(0, y_top - t):min(size, y_top + t + 1), x] = 1
        img[max(0, y_bot - t):min(size, y_bot + t + 1), x] = 1

    for y in range(y0, y1 + 1):
        x_left = x0 + int(rng.integers(-wobble, wobble + 1))
        x_right = x1 + int(rng.integers(-wobble, wobble + 1))
        x_left = max(0, min(size - 1, x_left))
        x_right = max(0, min(size - 1, x_right))
        img[y, max(0, x_left - t):min(size, x_left + t + 1)] = 1
        img[y, max(0, x_right - t):min(size, x_right + t + 1)] = 1

    # occasionally add some interior pixels (imperfect fill)
    if rng.random() < fill_prob:
        fill_mask = rng.random((y1 - y0 + 1, x1 - x0 + 1)) < rng.uniform(0.02, 0.10)
        img[y0:y1 + 1, x0:x1 + 1] |= fill_mask.astype(np.uint8)

    return img

def gen_line(size=60, rng=None,
             thickness_min=1, thickness_max=3,
             angle_choices=None,
             center_jitter=6,
             length_min=30, length_max=56,
             broken_prob=0.35) -> np.ndarray:
    """Imperfect line segment at random angle; sometimes broken."""
    if rng is None:
        rng = np.random.default_rng()
    img = np.zeros((size, size), dtype=np.uint8)

    if angle_choices is None:
        # prefer some easy angles but allow random too
        if rng.random() < 0.7:
            angle = float(rng.choice([0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165]))
        else:
            angle = float(rng.uniform(0, 180))
    else:
        angle = float(rng.choice(angle_choices))

    theta = math.radians(angle)
    cx = size // 2 + int(rng.integers(-center_jitter, center_jitter + 1))
    cy = size // 2 + int(rng.integers(-center_jitter, center_jitter + 1))
    length = int(rng.integers(length_min, length_max + 1))
    t = int(rng.integers(thickness_min, thickness_max + 1))

    # endpoints
    dx = math.cos(theta) * (length / 2.0)
    dy = math.sin(theta) * (length / 2.0)
    x0, y0 = cx - dx, cy - dy
    x1, y1 = cx + dx, cy + dy

    # rasterize segment by sampling points along it
    steps = max(2, int(length * 2))
    for i in range(steps + 1):
        u = i / steps
        x = int(round(x0 * (1 - u) + x1 * u))
        y = int(round(y0 * (1 - u) + y1 * u))
        if 0 <= x < size and 0 <= y < size:
            img[max(0, y - t):min(size, y + t + 1), max(0, x - t):min(size, x + t + 1)] = 1

    # sometimes break the line (remove a chunk)
    if rng.random() < broken_prob:
        cut_len = int(rng.integers(max(2, steps // 6), max(3, steps // 3)))
        cut_start = int(rng.integers(0, max(1, steps - cut_len)))
        for i in range(cut_start, cut_start + cut_len):
            u = i / steps
            x = int(round(x0 * (1 - u) + x1 * u))
            y = int(round(y0 * (1 - u) + y1 * u))
            if 0 <= x < size and 0 <= y < size:
                img[max(0, y - t):min(size, y + t + 1), max(0, x - t):min(size, x + t + 1)] = 0

    return img

def make_dataset(n_per_class: int,
                 size=60,
                 noise_flip=0.01,
                 drop_on=0.02,
                 rng=None):
    """
    Returns:
      X: (N, 3600) float32 in {0,1}
      y: (N,) int64 in {0,1,2}  (0=circle,1=square,2=line)
    """
    if rng is None:
        rng = np.random.default_rng()

    X_list = []
    y_list = []

    for _ in range(n_per_class):
        img = gen_circle(size=size, rng=rng)
        img = _add_dropout(img, drop_on, rng)
        img = _add_salt_pepper(img, noise_flip, rng)
        X_list.append(img.reshape(-1).astype(np.float32))
        y_list.append(0)

    for _ in range(n_per_class):
        img = gen_square(size=size, rng=rng)
        img = _add_dropout(img, drop_on, rng)
        img = _add_salt_pepper(img, noise_flip, rng)
        X_list.append(img.reshape(-1).astype(np.float32))
        y_list.append(1)

    for _ in range(n_per_class):
        img = gen_line(size=size, rng=rng)
        img = _add_dropout(img, drop_on, rng)
        img = _add_salt_pepper(img, noise_flip, rng)
        X_list.append(img.reshape(-1).astype(np.float32))
        y_list.append(2)

    X = np.stack(X_list, axis=0)
    y = np.array(y_list, dtype=np.int64)

    # shuffle
    idx = rng.permutation(len(y))
    return X[idx], y[idx]


# -----------------------------
# Model
# -----------------------------

class MLP2(nn.Module):
    def __init__(self, in_dim=3600, hidden=64, out_dim=3):
        super().__init__()
        self.fc1 = nn.Linear(in_dim, hidden, bias=True)
        self.fc2 = nn.Linear(hidden, out_dim, bias=True)

    def forward(self, x):
        z1 = self.fc1(x)
        a1 = F.relu(z1)
        z2 = self.fc2(a1)
        return z2


# -----------------------------
# Quantization helpers
# -----------------------------

def quantize_int8_symmetric_per_tensor(w_float: torch.Tensor):
    """
    Symmetric per-tensor int8 quantization.
    Returns:
      w_q: torch.int8
      scale: float32 (python float)
    """
    with torch.no_grad():
        max_abs = w_float.abs().max().item()
        if max_abs == 0.0 or not math.isfinite(max_abs):
            scale = 1.0
            w_q = torch.zeros_like(w_float, dtype=torch.int8)
            return w_q, scale

        scale = max_abs / 127.0  # maps max_abs -> 127
        # NOTE: clamp includes -128..127 to match int8 range; with scale based on 127
        w_q = torch.round(w_float / scale).clamp(-128, 127).to(torch.int8)
        return w_q, float(scale)

def quantize_bias_to_int32(b_float: torch.Tensor, weight_scale: float):
    """
    Bias int32 in "accumulator domain" for int8 MAC with input scale=1.
    We want: (acc_int32 + b_int32)*weight_scale ~ acc_float + b_float
    => b_int32 ~ b_float / weight_scale
    """
    with torch.no_grad():
        if weight_scale == 0.0 or not math.isfinite(weight_scale):
            weight_scale = 1.0
        b_q = torch.round(b_float / weight_scale).clamp(-(2**31), 2**31 - 1).to(torch.int32)
        return b_q

def requant_relu_int32_to_int8(a_int32: torch.Tensor, shift: int):
    """
    a_int32 is assumed >=0 (after ReLU).
    Rounding: add (1<<(shift-1)) then >> shift (arithmetic right shift is same as logical for nonneg)
    Clamp to [0,127] then cast to int8.
    """
    if shift < 0:
        raise ValueError("shift must be >= 0")

    with torch.no_grad():
        if shift == 0:
            y = a_int32
        else:
            rnd = (1 << (shift - 1))
            y = (a_int32 + rnd) >> shift

        y = torch.clamp(y, 0, 127)
        return y.to(torch.int8)

def choose_shift(calib_a1_int32: torch.Tensor, shift_min=0, shift_max=20):
    """
    Heuristic SHIFT search. Reports saturation and picks a shift that:
      - keeps saturation low
      - keeps outputs reasonably "alive" (not all zeros)
    Returns: best_shift, stats_dict_for_best, all_stats_list
    """
    # calib_a1_int32: (N, H), int32 >= 0
    assert calib_a1_int32.dtype == torch.int32
    assert (calib_a1_int32 >= 0).all().item()

    all_stats = []
    best = None

    for s in range(shift_min, shift_max + 1):
        a_q = requant_relu_int32_to_int8(calib_a1_int32, s).to(torch.int16)  # safe for stats
        sat = (a_q == 127).float().mean().item()
        nz = (a_q > 0).float().mean().item()
        mean = a_q.float().mean().item()
        med = a_q.float().median().item()

        # objective: lower is better
        # - heavy penalty for saturation
        # - penalty if too sparse (dead)
        # - penalty if mean too tiny (all near 0) or too huge (likely to saturate later)
        target_mean = 24.0
        obj = (sat * 10.0) + (max(0.0, 0.20 - nz) * 3.0) + (abs(mean - target_mean) / target_mean)

        stats = {
            "shift": s,
            "sat_pct": sat * 100.0,
            "nonzero_pct": nz * 100.0,
            "mean": mean,
            "median": med,
            "obj": obj,
        }
        all_stats.append(stats)

        if best is None or obj < best["obj"]:
            best = stats

    return best["shift"], best, all_stats


# -----------------------------
# Integer inference emulation
# -----------------------------

@torch.no_grad()
def int_infer_batch(x_bin_float: torch.Tensor,
                    w1_q: torch.Tensor, b1_q: torch.Tensor,
                    w2_q: torch.Tensor, b2_q: torch.Tensor,
                    shift: int):
    """
    x_bin_float: (N, 3600) float32 in {0,1}. We will convert to int32 0/1.
    w1_q: (64,3600) int8
    b1_q: (64,) int32
    w2_q: (3,64) int8
    b2_q: (3,) int32
    Returns:
      logits_int32: (N,3) int32
      pred: (N,) int64
    """
    # Explicit signed conversions
    x_i32 = x_bin_float.to(torch.int32)  # values 0/1
    w1_i32 = w1_q.to(torch.int32)
    w2_i32 = w2_q.to(torch.int32)

    # layer1: (N,64) = (N,3600) @ (3600,64)
    # w1 is (64,3600), so use transpose
    a1_i32 = x_i32.matmul(w1_i32.t()) + b1_q.view(1, -1)  # int32
    a1_i32 = torch.clamp(a1_i32, min=0)  # ReLU

    a1_q = requant_relu_int32_to_int8(a1_i32, shift)  # int8 in [0,127]
    a1_q_i32 = a1_q.to(torch.int32)

    # layer2: (N,3) = (N,64) @ (64,3)
    logits_i32 = a1_q_i32.matmul(w2_i32.t()) + b2_q.view(1, -1)
    pred = torch.argmax(logits_i32, dim=1)
    return logits_i32, pred


# -----------------------------
# Training / evaluation
# -----------------------------

@torch.no_grad()
def eval_float(model: nn.Module, x: torch.Tensor, y: torch.Tensor, batch_size: int, device: str):
    model.eval()
    n = x.shape[0]
    correct = 0
    total = 0
    for i in range(0, n, batch_size):
        xb = x[i:i+batch_size].to(device)
        yb = y[i:i+batch_size].to(device)
        logits = model(xb)
        pred = torch.argmax(logits, dim=1)
        correct += (pred == yb).sum().item()
        total += yb.numel()
    return correct / max(1, total)

def train(model: nn.Module, x_train: torch.Tensor, y_train: torch.Tensor,
          x_val: torch.Tensor, y_val: torch.Tensor,
          epochs: int, lr: float, batch_size: int, device: str, weight_clip: float):
    model.to(device)
    opt = torch.optim.Adam(model.parameters(), lr=lr)
    criterion = nn.CrossEntropyLoss()

    n = x_train.shape[0]

    for ep in range(1, epochs + 1):
        model.train()
        perm = torch.randperm(n, device=device)

        total_loss = 0.0
        total = 0

        for i in range(0, n, batch_size):
            idx = perm[i:i+batch_size]
            xb = x_train[idx].to(device)
            yb = y_train[idx].to(device)

            opt.zero_grad(set_to_none=True)
            logits = model(xb)
            loss = criterion(logits, yb)
            loss.backward()
            opt.step()

            # mild clipping to encourage int8-friendly weights
            with torch.no_grad():
                for p in model.parameters():
                    if p.dim() >= 2:  # weights
                        p.clamp_(-weight_clip, weight_clip)

            total_loss += loss.item() * yb.numel()
            total += yb.numel()

        train_acc = eval_float(model, x_train, y_train, batch_size, device)
        val_acc = eval_float(model, x_val, y_val, batch_size, device)
        avg_loss = total_loss / max(1, total)

        print(f"Epoch {ep:02d}/{epochs}  loss={avg_loss:.4f}  train_acc={train_acc*100:.2f}%  val_acc={val_acc*100:.2f}%")

    return model


# -----------------------------
# Export helpers
# -----------------------------

def save_matrix_txt(path: str, arr: np.ndarray):
    """
    Saves 2D array as text, one row per line, space-separated integers.
    """
    with open(path, "w", encoding="utf-8") as f:
        if arr.ndim == 1:
            f.write(" ".join(str(int(x)) for x in arr.tolist()) + "\n")
        else:
            for r in range(arr.shape[0]):
                f.write(" ".join(str(int(x)) for x in arr[r].tolist()) + "\n")

def write_report(path: str, lines: list[str]):
    with open(path, "w", encoding="utf-8") as f:
        for ln in lines:
            f.write(ln.rstrip() + "\n")


# -----------------------------
# Main
# -----------------------------

def main():
    ap = argparse.ArgumentParser(description="Train + quantize 2-layer MLP for 60x60 binary images (circle/square/line).")
    ap.add_argument("--seed", type=int, default=123)
    ap.add_argument("--device", type=str, default="cuda" if torch.cuda.is_available() else "cpu")
    ap.add_argument("--epochs", type=int, default=20)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--batch_size", type=int, default=128)
    ap.add_argument("--hidden", type=int, default=64)
    ap.add_argument("--train_per_class", type=int, default=2000)
    ap.add_argument("--val_per_class", type=int, default=600)
    ap.add_argument("--noise_flip", type=float, default=0.012, help="salt/pepper flip probability")
    ap.add_argument("--drop_on", type=float, default=0.02, help="dropout of 'on' pixels probability")
    ap.add_argument("--weight_clip", type=float, default=2.0)
    ap.add_argument("--shift_min", type=int, default=0)
    ap.add_argument("--shift_max", type=int, default=20)
    ap.add_argument("--export_dir", type=str, default="export_mlp_int")
    args = ap.parse_args()

    # Repro
    np_rng = np.random.default_rng(args.seed)
    torch.manual_seed(args.seed)

    os.makedirs(args.export_dir, exist_ok=True)

    # Data
    Xtr_np, ytr_np = make_dataset(
        n_per_class=args.train_per_class,
        noise_flip=args.noise_flip,
        drop_on=args.drop_on,
        rng=np_rng
    )
    Xva_np, yva_np = make_dataset(
        n_per_class=args.val_per_class,
        noise_flip=args.noise_flip,
        drop_on=args.drop_on,
        rng=np_rng
    )

    x_train = torch.from_numpy(Xtr_np)  # float32 0/1
    y_train = torch.from_numpy(ytr_np)  # int64
    x_val = torch.from_numpy(Xva_np)
    y_val = torch.from_numpy(yva_np)

    # Model
    model = MLP2(in_dim=3600, hidden=args.hidden, out_dim=3)

    # Train
    model = train(
        model, x_train, y_train, x_val, y_val,
        epochs=args.epochs,
        lr=args.lr,
        batch_size=args.batch_size,
        device=args.device,
        weight_clip=args.weight_clip
    )

    float_val_acc = eval_float(model, x_val, y_val, args.batch_size, args.device)
    print(f"Float model val accuracy: {float_val_acc*100:.2f}%")

    # -----------------------------
    # Post-training quantization
    # -----------------------------
    with torch.no_grad():
        w1_f = model.fc1.weight.detach().cpu()  # (64,3600)
        b1_f = model.fc1.bias.detach().cpu()    # (64,)
        w2_f = model.fc2.weight.detach().cpu()  # (3,64)
        b2_f = model.fc2.bias.detach().cpu()    # (3,)

    w1_q, s_w1 = quantize_int8_symmetric_per_tensor(w1_f)
    w2_q, s_w2 = quantize_int8_symmetric_per_tensor(w2_f)

    b1_q = quantize_bias_to_int32(b1_f, s_w1)
    b2_q = quantize_bias_to_int32(b2_f, s_w2)

    # Check ranges explicitly (debug/assurance)
    assert w1_q.dtype == torch.int8 and w2_q.dtype == torch.int8
    assert b1_q.dtype == torch.int32 and b2_q.dtype == torch.int32

    # -----------------------------
    # Choose SHIFT using calibration activations
    # -----------------------------
    # Use a subset of val as calibration set (or all)
    calib_x = x_val[: min(1024, x_val.shape[0])].cpu()

    with torch.no_grad():
        # integer layer1 accumulator for calibration
        x_i32 = calib_x.to(torch.int32)        # 0/1
        w1_i32 = w1_q.to(torch.int32)
        a1_i32 = x_i32.matmul(w1_i32.t()) + b1_q.view(1, -1)  # (N,64) int32
        a1_i32 = torch.clamp(a1_i32, min=0)

    best_shift, best_stats, all_stats = choose_shift(a1_i32, args.shift_min, args.shift_max)

    print("SHIFT search results (top 5 by objective):")
    all_stats_sorted = sorted(all_stats, key=lambda d: d["obj"])
    for s in all_stats_sorted[:5]:
        print(f"  SHIFT={s['shift']:2d}  sat={s['sat_pct']:.2f}%  nonzero={s['nonzero_pct']:.2f}%  mean={s['mean']:.2f}  median={s['median']:.2f}")

    SHIFT = best_shift
    print(f"Chosen SHIFT = {SHIFT}  (sat={best_stats['sat_pct']:.2f}%, nonzero={best_stats['nonzero_pct']:.2f}%, mean={best_stats['mean']:.2f}, median={best_stats['median']:.2f})")

    # -----------------------------
    # Integer-only inference check
    # -----------------------------
    with torch.no_grad():
        # float predictions (original float model)
        model.eval()
        logits_f = model(x_val.to(args.device)).cpu()
        pred_f = torch.argmax(logits_f, dim=1)

        # integer predictions (emulation)
        logits_i32, pred_i = int_infer_batch(
            x_val.cpu(),
            w1_q, b1_q,
            w2_q, b2_q,
            SHIFT
        )

        match = (pred_f == pred_i).float().mean().item()
        int_acc = (pred_i == y_val).float().mean().item()
        float_acc = (pred_f == y_val).float().mean().item()

    print(f"Argmax match rate (float vs int emu): {match*100:.2f}%")
    print(f"Val acc: float={float_acc*100:.2f}%  int_emu={int_acc*100:.2f}%")

    # -----------------------------
    # Export
    # -----------------------------
    export_dir = args.export_dir

    # Convert to numpy with explicit signed dtypes
    W1_np = w1_q.numpy().astype(np.int8)         # (64,3600)
    b1_np = b1_q.numpy().astype(np.int32)        # (64,)
    W2_np = w2_q.numpy().astype(np.int8)         # (3,64)
    b2_np = b2_q.numpy().astype(np.int32)        # (3,)

    # Save matrices as text
    save_matrix_txt(os.path.join(export_dir, "W1_int8.txt"), W1_np)
    save_matrix_txt(os.path.join(export_dir, "b1_int32.txt"), b1_np)
    save_matrix_txt(os.path.join(export_dir, "W2_int8.txt"), W2_np)
    save_matrix_txt(os.path.join(export_dir, "b2_int32.txt"), b2_np)
    write_report(os.path.join(export_dir, "SHIFT.txt"), [str(int(SHIFT))])

    # Report (includes scales so you know what float-domain these integers correspond to)
    report_lines = []
    report_lines.append("=== 2-layer MLP export report ===")
    report_lines.append(f"Class mapping: 0=circle, 1=square, 2=line")
    report_lines.append("")
    report_lines.append("Shapes:")
    report_lines.append(f"  W1: {tuple(W1_np.shape)} int8")
    report_lines.append(f"  b1: {tuple(b1_np.shape)} int32")
    report_lines.append(f"  W2: {tuple(W2_np.shape)} int8")
    report_lines.append(f"  b2: {tuple(b2_np.shape)} int32")
    report_lines.append("")
    report_lines.append("Quantization:")
    report_lines.append(f"  W1 symmetric per-tensor scale s_w1 = {s_w1:.8g}  (w_float ~= w_int8 * s_w1)")
    report_lines.append(f"  W2 symmetric per-tensor scale s_w2 = {s_w2:.8g}  (w_float ~= w_int8 * s_w2)")
    report_lines.append(f"  b1_int32 = round(b1_float / s_w1)")
    report_lines.append(f"  b2_int32 = round(b2_float / s_w2)")
    report_lines.append("")
    report_lines.append("Activation requant (after ReLU):")
    report_lines.append(f"  SHIFT = {SHIFT}")
    report_lines.append(f"  a1_q = clamp( ((a1_int32 + (1<<(SHIFT-1))) >> SHIFT), 0..127 )  [SHIFT=0 => no rounding/shift]")
    report_lines.append(f"  Chosen SHIFT stats: sat={best_stats['sat_pct']:.3f}%  nonzero={best_stats['nonzero_pct']:.3f}%  mean={best_stats['mean']:.3f}  median={best_stats['median']:.3f}")
    report_lines.append("")
    report_lines.append("Accuracy / consistency:")
    report_lines.append(f"  Float val accuracy: {float_val_acc*100:.2f}%")
    report_lines.append(f"  Integer emu val accuracy: {int_acc*100:.2f}%")
    report_lines.append(f"  Argmax match (float preds vs int emu preds): {match*100:.2f}%")
    report_lines.append("")
    report_lines.append("Notes / assumptions (important for hardware matching):")
    report_lines.append("  - Input x is treated as int32 0/1 (no input scaling).")
    report_lines.append("  - MAC is emulated as int8->int32 accumulation using signed weights; input is nonnegative.")
    report_lines.append("  - Biases are exported in the same int32 accumulator domain used by the MAC sums.")
    report_lines.append("  - Layer2 uses a1_q (0..127) directly as int8 activations; its scale is implicit via SHIFT.")
    report_lines.append("")
    report_lines.append(f"Files written to: {os.path.abspath(export_dir)}")
    report_lines.append("  - W1_int8.txt, b1_int32.txt, W2_int8.txt, b2_int32.txt, SHIFT.txt, report.txt")

    write_report(os.path.join(export_dir, "report.txt"), report_lines)

    print(f"Export complete -> {os.path.abspath(export_dir)}")


if __name__ == "__main__":
    main()
