.text
.globl _start

_start:
    # x2 = base word-address 58636 (addresses increment by 1 word)
    lui x2, 14
    addi x2, x2, 1292

    # [01/64]
    lui x1, 0
    addi x1, x1, 11
    sw x1, 0(x2)    # x2=58636  x1=11
    addi x2, x2, 1

    # [02/64]
    lui x1, 0
    addi x1, x1, 8
    sw x1, 0(x2)    # x2=58637  x1=8
    addi x2, x2, 1

    # [03/64]
    lui x1, 0
    addi x1, x1, -57
    sw x1, 0(x2)    # x2=58638  x1=-57
    addi x2, x2, 1

    # [04/64]
    lui x1, 0
    addi x1, x1, 49
    sw x1, 0(x2)    # x2=58639  x1=49
    addi x2, x2, 1

    # [05/64]
    lui x1, 0
    addi x1, x1, 63
    sw x1, 0(x2)    # x2=58640  x1=63
    addi x2, x2, 1

    # [06/64]
    lui x1, 0
    addi x1, x1, 29
    sw x1, 0(x2)    # x2=58641  x1=29
    addi x2, x2, 1

    # [07/64]
    lui x1, 0
    addi x1, x1, -22
    sw x1, 0(x2)    # x2=58642  x1=-22
    addi x2, x2, 1

    # [08/64]
    lui x1, 0
    addi x1, x1, 59
    sw x1, 0(x2)    # x2=58643  x1=59
    addi x2, x2, 1

    # [09/64]
    lui x1, 0
    addi x1, x1, -11
    sw x1, 0(x2)    # x2=58644  x1=-11
    addi x2, x2, 1

    # [10/64]
    lui x1, 0
    addi x1, x1, 21
    sw x1, 0(x2)    # x2=58645  x1=21
    addi x2, x2, 1

    # [11/64]
    lui x1, 0
    addi x1, x1, 32
    sw x1, 0(x2)    # x2=58646  x1=32
    addi x2, x2, 1

    # [12/64]
    lui x1, 0
    addi x1, x1, -56
    sw x1, 0(x2)    # x2=58647  x1=-56
    addi x2, x2, 1

    # [13/64]
    lui x1, 0
    addi x1, x1, -82
    sw x1, 0(x2)    # x2=58648  x1=-82
    addi x2, x2, 1

    # [14/64]
    lui x1, 0
    addi x1, x1, -12
    sw x1, 0(x2)    # x2=58649  x1=-12
    addi x2, x2, 1

    # [15/64]
    lui x1, 0
    addi x1, x1, -54
    sw x1, 0(x2)    # x2=58650  x1=-54
    addi x2, x2, 1

    # [16/64]
    lui x1, 0
    addi x1, x1, -28
    sw x1, 0(x2)    # x2=58651  x1=-28
    addi x2, x2, 1

    # [17/64]
    lui x1, 0
    addi x1, x1, 58
    sw x1, 0(x2)    # x2=58652  x1=58
    addi x2, x2, 1

    # [18/64]
    lui x1, 0
    addi x1, x1, 59
    sw x1, 0(x2)    # x2=58653  x1=59
    addi x2, x2, 1

    # [19/64]
    lui x1, 0
    addi x1, x1, 45
    sw x1, 0(x2)    # x2=58654  x1=45
    addi x2, x2, 1

    # [20/64]
    lui x1, 0
    addi x1, x1, 31
    sw x1, 0(x2)    # x2=58655  x1=31
    addi x2, x2, 1

    # [21/64]
    lui x1, 0
    addi x1, x1, -43
    sw x1, 0(x2)    # x2=58656  x1=-43
    addi x2, x2, 1

    # [22/64]
    lui x1, 0
    addi x1, x1, 47
    sw x1, 0(x2)    # x2=58657  x1=47
    addi x2, x2, 1

    # [23/64]
    lui x1, 0
    addi x1, x1, 4
    sw x1, 0(x2)    # x2=58658  x1=4
    addi x2, x2, 1

    # [24/64]
    lui x1, 0
    addi x1, x1, -45
    sw x1, 0(x2)    # x2=58659  x1=-45
    addi x2, x2, 1

    # [25/64]
    lui x1, 0
    addi x1, x1, 45
    sw x1, 0(x2)    # x2=58660  x1=45
    addi x2, x2, 1

    # [26/64]
    lui x1, 0
    addi x1, x1, 40
    sw x1, 0(x2)    # x2=58661  x1=40
    addi x2, x2, 1

    # [27/64]
    lui x1, 0
    addi x1, x1, -46
    sw x1, 0(x2)    # x2=58662  x1=-46
    addi x2, x2, 1

    # [28/64]
    lui x1, 0
    addi x1, x1, 67
    sw x1, 0(x2)    # x2=58663  x1=67
    addi x2, x2, 1

    # [29/64]
    lui x1, 0
    addi x1, x1, 76
    sw x1, 0(x2)    # x2=58664  x1=76
    addi x2, x2, 1

    # [30/64]
    lui x1, 0
    addi x1, x1, -30
    sw x1, 0(x2)    # x2=58665  x1=-30
    addi x2, x2, 1

    # [31/64]
    lui x1, 0
    addi x1, x1, -47
    sw x1, 0(x2)    # x2=58666  x1=-47
    addi x2, x2, 1

    # [32/64]
    lui x1, 0
    addi x1, x1, 105
    sw x1, 0(x2)    # x2=58667  x1=105
    addi x2, x2, 1

    # [33/64]
    lui x1, 0
    addi x1, x1, 38
    sw x1, 0(x2)    # x2=58668  x1=38
    addi x2, x2, 1

    # [34/64]
    lui x1, 0
    addi x1, x1, -19
    sw x1, 0(x2)    # x2=58669  x1=-19
    addi x2, x2, 1

    # [35/64]
    lui x1, 0
    addi x1, x1, -17
    sw x1, 0(x2)    # x2=58670  x1=-17
    addi x2, x2, 1

    # [36/64]
    lui x1, 0
    addi x1, x1, -64
    sw x1, 0(x2)    # x2=58671  x1=-64
    addi x2, x2, 1

    # [37/64]
    lui x1, 0
    addi x1, x1, -39
    sw x1, 0(x2)    # x2=58672  x1=-39
    addi x2, x2, 1

    # [38/64]
    lui x1, 0
    addi x1, x1, 55
    sw x1, 0(x2)    # x2=58673  x1=55
    addi x2, x2, 1

    # [39/64]
    lui x1, 0
    addi x1, x1, -50
    sw x1, 0(x2)    # x2=58674  x1=-50
    addi x2, x2, 1

    # [40/64]
    lui x1, 0
    addi x1, x1, -22
    sw x1, 0(x2)    # x2=58675  x1=-22
    addi x2, x2, 1

    # [41/64]
    lui x1, 0
    addi x1, x1, -49
    sw x1, 0(x2)    # x2=58676  x1=-49
    addi x2, x2, 1

    # [42/64]
    lui x1, 0
    addi x1, x1, 33
    sw x1, 0(x2)    # x2=58677  x1=33
    addi x2, x2, 1

    # [43/64]
    lui x1, 0
    addi x1, x1, -2
    sw x1, 0(x2)    # x2=58678  x1=-2
    addi x2, x2, 1

    # [44/64]
    lui x1, 0
    addi x1, x1, -27
    sw x1, 0(x2)    # x2=58679  x1=-27
    addi x2, x2, 1

    # [45/64]
    lui x1, 0
    addi x1, x1, 77
    sw x1, 0(x2)    # x2=58680  x1=77
    addi x2, x2, 1

    # [46/64]
    lui x1, 0
    addi x1, x1, 56
    sw x1, 0(x2)    # x2=58681  x1=56
    addi x2, x2, 1

    # [47/64]
    lui x1, 0
    addi x1, x1, -58
    sw x1, 0(x2)    # x2=58682  x1=-58
    addi x2, x2, 1

    # [48/64]
    lui x1, 0
    addi x1, x1, -21
    sw x1, 0(x2)    # x2=58683  x1=-21
    addi x2, x2, 1

    # [49/64]
    lui x1, 0
    addi x1, x1, 74
    sw x1, 0(x2)    # x2=58684  x1=74
    addi x2, x2, 1

    # [50/64]
    lui x1, 0
    addi x1, x1, 40
    sw x1, 0(x2)    # x2=58685  x1=40
    addi x2, x2, 1

    # [51/64]
    lui x1, 0
    addi x1, x1, -67
    sw x1, 0(x2)    # x2=58686  x1=-67
    addi x2, x2, 1

    # [52/64]
    lui x1, 0
    addi x1, x1, -36
    sw x1, 0(x2)    # x2=58687  x1=-36
    addi x2, x2, 1

    # [53/64]
    lui x1, 0
    addi x1, x1, 48
    sw x1, 0(x2)    # x2=58688  x1=48
    addi x2, x2, 1

    # [54/64]
    lui x1, 0
    addi x1, x1, 36
    sw x1, 0(x2)    # x2=58689  x1=36
    addi x2, x2, 1

    # [55/64]
    lui x1, 0
    addi x1, x1, 68
    sw x1, 0(x2)    # x2=58690  x1=68
    addi x2, x2, 1

    # [56/64]
    lui x1, 0
    addi x1, x1, 50
    sw x1, 0(x2)    # x2=58691  x1=50
    addi x2, x2, 1

    # [57/64]
    lui x1, 0
    addi x1, x1, 3
    sw x1, 0(x2)    # x2=58692  x1=3
    addi x2, x2, 1

    # [58/64]
    lui x1, 0
    addi x1, x1, -13
    sw x1, 0(x2)    # x2=58693  x1=-13
    addi x2, x2, 1

    # [59/64]
    lui x1, 0
    addi x1, x1, 53
    sw x1, 0(x2)    # x2=58694  x1=53
    addi x2, x2, 1

    # [60/64]
    lui x1, 0
    addi x1, x1, -15
    sw x1, 0(x2)    # x2=58695  x1=-15
    addi x2, x2, 1

    # [61/64]
    lui x1, 0
    addi x1, x1, -65
    sw x1, 0(x2)    # x2=58696  x1=-65
    addi x2, x2, 1

    # [62/64]
    lui x1, 0
    addi x1, x1, -8
    sw x1, 0(x2)    # x2=58697  x1=-8
    addi x2, x2, 1

    # [63/64]
    lui x1, 0
    addi x1, x1, -59
    sw x1, 0(x2)    # x2=58698  x1=-59
    addi x2, x2, 1

    # [64/64]
    lui x1, 0
    addi x1, x1, 28
    sw x1, 0(x2)    # x2=58699  x1=28
