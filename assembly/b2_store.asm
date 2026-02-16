# asm to store the 3 int32s for b2 in tensor memory
# base address is 58764
# use x1, x2

addi x1, x0, 16
lui x2, 14
addi x2, x2, 1420
sw x1, 0(x2)

addi x1, x0, -21
addi x2, x2, 1
sw x1, 0(x2)

addi x1, x0, 17
addi x2, x2, 1
sw x1, 0(x2)
