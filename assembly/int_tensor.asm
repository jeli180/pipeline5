    .section .text
    .globl _start

# ------------------------------------------------------------
# Shape IDs
#   0 = circle outline
#   1 = square outline
#   2 = line
#
# Memory map
#   Q1 base =   12
#   Q2 base =  464
#   Q3 base =  916
#   Q4 base = 1368
#
# Each shape:
#   60 x 60 = 3600 bits = 113 words
# ------------------------------------------------------------

_start:

    # Quadrant 1: circle outline at base 12
    addi x10, x0, 12
    addi x11, x0, 0
    jal  x1, render_shape

    # Quadrant 2: square outline at base 464
    addi x10, x0, 464
    addi x11, x0, 1
    jal  x1, render_shape

    # Quadrant 3: vertical line at base 916
    addi x10, x0, 916
    addi x11, x0, 2
    jal  x1, render_shape

    # Quadrant 4: circle outline at base 1368
    addi x10, x0, 1368
    addi x11, x0, 0
    jal  x1, render_shape

    # all shapes generated and stored to dcache
    # start inference

    start_inference:
    # set base address for tensor controller
    lui x30, 0xE
    addi x30, x30, 1424 # make x30 base address for tensor controller (58780)

    # load shift value to tensor_controller
    addi x1, x0, 6
    sw x1, 12(x30) # store 6 to shift register

    # setup 4 dcache memory pointers to start at quadrant base addr
    addi x15, x0, 113
    slli x15, x15, 2 # dcache addr gap between quadrants (3600 / 32 = 112.5 round up to 113 and each address is 4 apart)
    # x11 is q1, x12 is q2, x13 is q3, x14 is q4
    addi x11, x0, 12
    add x12, x11, x15
    add x13, x12, x15
    add x14, x13, x15

    # init tensor
    sw x0, 4(x30)
    addi x10, x0, 0 
    addi x4, x0, 1
    addi x5, x0, 2
    addi x6, x0, 3
    addi x17, x0, 255
    slli x18, x17, 8
    slli x19, x17, 16
    slli x20, x17, 24

    # x30, x11-14, x15/x10 for tracking RESERVED, x1(sent to tc)
    # x17-20 are masks for which byte were on
    # x3 is status (1 means byte 1 loaded to x1, 2 means byte 2 loaded to x1, etc)
    # get 32b bus for each quadrant from dcache, load into x21-24, mask into x25-28
    get_tc_pixel:
    add x25, x10, x11
    add x26, x10, x12
    add x27, x10, x13
    add x28, x10, x14

    lw x21, 0(x25)
    lw x22, 0(x26)
    lw x23, 0(x27)
    lw x24, 0(x28)

    addi x10, x10, 4 # point to next pixel bus

    # prepare first bus using byte 1 mask
    and x25, x21, x17
    and x26, x22, x17
    and x27, x23, x17
    and x28, x24, x17

    # shift into correct position
    slli x26, x26, 8
    slli x27, x27, 16
    slli x28, x28, 24

    addi x1, x0, 0 # reset x1
    or x1, x1, x25
    or x1, x1, x26
    or x1, x1, x27
    or x1, x1, x28

    addi x3, x4, 0 # update status

    jal x0, send_tensor_pixel

    fill_second: # also check if x10 = x15 for full done 
    # mask
    and x25, x21, x18
    and x26, x22, x18
    and x27, x23, x18
    and x28, x24, x18

    # shift
    srli x25, x25, 8
    slli x27, x27, 8
    slli x28, x28, 16

    addi x1, x0, 0
    or x1, x1, x25
    or x1, x1, x26
    or x1, x1, x27
    or x1, x1, x28

    beq x10, x15, send_tensor_last
    addi x3, x5, 0
    jal x0, send_tensor_pixel

    fill_third:
    # mask
    and x25, x21, x19
    and x26, x22, x19
    and x27, x23, x19
    and x28, x24, x19

    # shift
    srli x25, x25, 16
    srli x26, x26, 8
    slli x28, x28, 8

    addi x1, x0, 0
    or x1, x1, x25
    or x1, x1, x26
    or x1, x1, x27
    or x1, x1, x28

    addi x3, x6, 0
    jal x0, send_tensor_pixel

    fill_fourth:
    # mask
    and x25, x21, x20
    and x26, x22, x20
    and x27, x23, x20
    and x28, x24, x20

    # shift
    srli x25, x25, 24
    srli x26, x26, 16
    srli x27, x27, 8

    addi x1, x0, 0
    or x1, x1, x25
    or x1, x1, x26
    or x1, x1, x27
    or x1, x1, x28

    addi x3, x0, 4
    jal x0, send_tensor_pixel

    send_tensor_pixel: # x1 is ready to be sent
    lw x2, 8(x30)
    beq x0, x2, send_tensor_pixel

    sw x1, 8(x30)
    beq x4, x3, fill_second
    beq x5, x3, fill_third
    beq x6, x3, fill_fourth
    jal x0, get_tc_pixel

    send_tensor_last:
    lw x2, 8(x30)
    beq x0, x2, send_tensor_last
    sw x1, 8(x30)
    jal x0, get_tensor_shape


    # only x30 matters
    get_tensor_shape:
    lui x20, 0x80000 # only bit 31 high

    get_tensor_shape_loop:
    lw x1, 4(x30)
    and x2, x1, x20
    beq x2, x0, get_tensor_shape_loop

    # shape valid, need to ack to tensor
    sw x0, 4(x30)

    # prep x3 with shape data
    addi x3, x0, 15
    slli x3, x3, 12

    addi x4, x0, 2047
    slli x4, x4, 1
    addi x4, x4, 1 # x4 is lsb 12b mask

    and x1, x1, x4
    or x3, x3, x1

    # x3 has shape data, write to x31 for tb
    addi x31, x3, 0

done:
    jal  x0, done


# ------------------------------------------------------------
# render_shape
#
# Inputs:
#   x10 = base address
#   x11 = shape_id
#
# Clobbers:
#   x12-x24
# ------------------------------------------------------------
render_shape:
    la   x20, circle_left
    addi x24, x0, 60          # constant 60

    addi x12, x0, 0           # row = 0
    addi x14, x0, 0           # current packed word
    addi x15, x0, 0           # bit position 0..31

row_loop:
    beq  x12, x24, shape_done
    addi x13, x0, 0           # col = 0

col_loop:
    beq  x13, x24, next_row

    addi x16, x0, 0           # pixel_on = 0 by default

    beq  x11, x0, pixel_circle_outline

    addi x19, x0, 1
    beq  x11, x19, pixel_square_outline

    jal  x0, pixel_line


# ------------------------------------------------------------
# Circle outline
# For each row:
#   left  = circle_left[row]
#   right = 59 - left
#
# A pixel is on only if:
#   col == left OR col == right
#
# Special case:
#   if left == 60 => empty row
#   if left == right => set only one pixel
# ------------------------------------------------------------
pixel_circle_outline:
    slli x21, x12, 2
    add  x21, x21, x20
    lw   x22, 0(x21)          # x22 = left

    beq  x22, x24, pixel_done # empty row if left == 60

    beq  x13, x22, circle_set

    addi x23, x0, 59
    sub  x23, x23, x22        # x23 = right
    beq  x13, x23, circle_set

    jal  x0, pixel_done

circle_set:
    addi x16, x0, 1
    jal  x0, pixel_done


# ------------------------------------------------------------
# Square outline
# Outer box:
#   rows 12..47
#   cols 12..47
#
# On if:
#   inside box AND on top/bottom/left/right border
# ------------------------------------------------------------
pixel_square_outline:
    addi x21, x0, 12          # min bound
    blt  x12, x21, pixel_done
    blt  x13, x21, pixel_done

    addi x22, x0, 48          # exclusive max bound
    bge  x12, x22, pixel_done
    bge  x13, x22, pixel_done

    # Now inside the box, check if on border
    addi x21, x0, 12
    beq  x12, x21, square_set
    beq  x13, x21, square_set

    addi x21, x0, 47
    beq  x12, x21, square_set
    beq  x13, x21, square_set

    jal  x0, pixel_done

square_set:
    addi x16, x0, 1
    jal  x0, pixel_done


# ------------------------------------------------------------
# Vertical line
# 4-pixel wide line at cols 28..31
# ------------------------------------------------------------
pixel_line:
    addi x23, x0, 28
    blt  x13, x23, pixel_done

    addi x23, x0, 32
    bge  x13, x23, pixel_done

    addi x16, x0, 1


# ------------------------------------------------------------
# Pack current pixel into current 32-bit word
# ------------------------------------------------------------
pixel_done:
    beq  x16, x0, skip_set

    addi x23, x0, 1
    sll  x23, x23, x15
    or   x14, x14, x23

skip_set:
    addi x15, x15, 1          # next bit position
    addi x13, x13, 1          # next col

    addi x23, x0, 32
    bne  x15, x23, col_loop

    # Current word full: store it
    sw   x14, 0(x10)
    addi x10, x10, 4
    addi x14, x0, 0
    addi x15, x0, 0

    jal  x0, col_loop

next_row:
    addi x12, x12, 1
    jal  x0, row_loop

shape_done:
    # Store final partial word (16 valid low bits for 3600 total bits)
    beq  x15, x0, render_ret
    sw   x14, 0(x10)

render_ret:
    jalr x0, x1, 0


# ------------------------------------------------------------
# Circle boundary lookup
# left bound per row for a symmetric 60x60 circle
# right bound = 59 - left
# 60 means empty row
# ------------------------------------------------------------
    .section .rodata
    .align 2

circle_left:
    .word 60
    .word 60
    .word 23
    .word 20
    .word 17
    .word 15
    .word 14
    .word 13
    .word 11
    .word 10
    .word 9
    .word 8
    .word 8
    .word 7
    .word 6
    .word 5
    .word 5
    .word 4
    .word 4
    .word 4
    .word 3
    .word 3
    .word 3
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 2
    .word 3
    .word 3
    .word 3
    .word 4
    .word 4
    .word 4
    .word 5
    .word 5
    .word 6
    .word 7
    .word 8
    .word 8
    .word 9
    .word 10
    .word 11
    .word 13
    .word 14
    .word 15
    .word 17
    .word 20
    .word 23
    .word 60
    .word 60
