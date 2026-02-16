.text
.globl _start

_start:
    # Pack 3x64 int8s into 64 words:
    #   word[7:0]   = line1[j] (signed int8)
    #   word[15:8]  = line2[j] (signed int8)
    #   word[23:16] = line3[j] (signed int8)
    #   word[31:24] = 0
    # Addresses are word-addressed and increment by 1 each store.

    # x2 = base word-address 58700
    lui  x2, 14
    addi x2, x2, 1356

    # addr 58700: bytes [-7, -32, -43] (top byte 0)
    lui  x1, 3422
    addi x1, x1, 249
    sw   x1, 0(x2)    # x2=58700  x1_bytes(dec)=[-7, -32, -43]  x1=0x00D5E0F9
    addi x2, x2, 1

    # addr 58701: bytes [32, 0, -25] (top byte 0)
    lui  x1, 3696
    addi x1, x1, 32
    sw   x1, 0(x2)    # x2=58701  x1_bytes(dec)=[32, 0, -25]  x1=0x00E70020
    addi x2, x2, 1

    # addr 58702: bytes [-65, 29, 7] (top byte 0)
    lui  x1, 114
    addi x1, x1, -577
    sw   x1, 0(x2)    # x2=58702  x1_bytes(dec)=[-65, 29, 7]  x1=0x00071DBF
    addi x2, x2, 1

    # addr 58703: bytes [-47, -32, 7] (top byte 0)
    lui  x1, 126
    addi x1, x1, 209
    sw   x1, 0(x2)    # x2=58703  x1_bytes(dec)=[-47, -32, 7]  x1=0x0007E0D1
    addi x2, x2, 1

    # addr 58704: bytes [-86, -110, 127] (top byte 0)
    lui  x1, 2041
    addi x1, x1, 682
    sw   x1, 0(x2)    # x2=58704  x1_bytes(dec)=[-86, -110, 127]  x1=0x007F92AA
    addi x2, x2, 1

    # addr 58705: bytes [45, -17, -43] (top byte 0)
    lui  x1, 3423
    addi x1, x1, -211
    sw   x1, 0(x2)    # x2=58705  x1_bytes(dec)=[45, -17, -43]  x1=0x00D5EF2D
    addi x2, x2, 1

    # addr 58706: bytes [33, 27, -33] (top byte 0)
    lui  x1, 3570
    addi x1, x1, -1247
    sw   x1, 0(x2)    # x2=58706  x1_bytes(dec)=[33, 27, -33]  x1=0x00DF1B21
    addi x2, x2, 1

    # addr 58707: bytes [33, -67, 43] (top byte 0)
    lui  x1, 700
    addi x1, x1, -735
    sw   x1, 0(x2)    # x2=58707  x1_bytes(dec)=[33, -67, 43]  x1=0x002BBD21
    addi x2, x2, 1

    # addr 58708: bytes [24, -14, -56] (top byte 0)
    lui  x1, 3215
    addi x1, x1, 536
    sw   x1, 0(x2)    # x2=58708  x1_bytes(dec)=[24, -14, -56]  x1=0x00C8F218
    addi x2, x2, 1

    # addr 58709: bytes [44, -52, -50] (top byte 0)
    lui  x1, 3309
    addi x1, x1, -980
    sw   x1, 0(x2)    # x2=58709  x1_bytes(dec)=[44, -52, -50]  x1=0x00CECC2C
    addi x2, x2, 1

    # addr 58710: bytes [46, -21, -56] (top byte 0)
    lui  x1, 3215
    addi x1, x1, -1234
    sw   x1, 0(x2)    # x2=58710  x1_bytes(dec)=[46, -21, -56]  x1=0x00C8EB2E
    addi x2, x2, 1

    # addr 58711: bytes [-55, 48, -21] (top byte 0)
    lui  x1, 3763
    addi x1, x1, 201
    sw   x1, 0(x2)    # x2=58711  x1_bytes(dec)=[-55, 48, -21]  x1=0x00EB30C9
    addi x2, x2, 1

    # addr 58712: bytes [26, 44, 2] (top byte 0)
    lui  x1, 35
    addi x1, x1, -998
    sw   x1, 0(x2)    # x2=58712  x1_bytes(dec)=[26, 44, 2]  x1=0x00022C1A
    addi x2, x2, 1

    # addr 58713: bytes [-23, 44, 44] (top byte 0)
    lui  x1, 707
    addi x1, x1, -791
    sw   x1, 0(x2)    # x2=58713  x1_bytes(dec)=[-23, 44, 44]  x1=0x002C2CE9
    addi x2, x2, 1

    # addr 58714: bytes [-37, 30, -32] (top byte 0)
    lui  x1, 3586
    addi x1, x1, -293
    sw   x1, 0(x2)    # x2=58714  x1_bytes(dec)=[-37, 30, -32]  x1=0x00E01EDB
    addi x2, x2, 1

    # addr 58715: bytes [14, -1, -34] (top byte 0)
    lui  x1, 3568
    addi x1, x1, -242
    sw   x1, 0(x2)    # x2=58715  x1_bytes(dec)=[14, -1, -34]  x1=0x00DEFF0E
    addi x2, x2, 1

    # addr 58716: bytes [22, -30, 47] (top byte 0)
    lui  x1, 766
    addi x1, x1, 534
    sw   x1, 0(x2)    # x2=58716  x1_bytes(dec)=[22, -30, 47]  x1=0x002FE216
    addi x2, x2, 1

    # addr 58717: bytes [-85, -21, 67] (top byte 0)
    lui  x1, 1087
    addi x1, x1, -1109
    sw   x1, 0(x2)    # x2=58717  x1_bytes(dec)=[-85, -21, 67]  x1=0x0043EBAB
    addi x2, x2, 1

    # addr 58718: bytes [-2, -49, 39] (top byte 0)
    lui  x1, 637
    addi x1, x1, -2
    sw   x1, 0(x2)    # x2=58718  x1_bytes(dec)=[-2, -49, 39]  x1=0x0027CFFE
    addi x2, x2, 1

    # addr 58719: bytes [-54, -28, 33] (top byte 0)
    lui  x1, 542
    addi x1, x1, 1226
    sw   x1, 0(x2)    # x2=58719  x1_bytes(dec)=[-54, -28, 33]  x1=0x0021E4CA
    addi x2, x2, 1

    # addr 58720: bytes [-49, 48, -21] (top byte 0)
    lui  x1, 3763
    addi x1, x1, 207
    sw   x1, 0(x2)    # x2=58720  x1_bytes(dec)=[-49, 48, -21]  x1=0x00EB30CF
    addi x2, x2, 1

    # addr 58721: bytes [39, -51, 54] (top byte 0)
    lui  x1, 877
    addi x1, x1, -729
    sw   x1, 0(x2)    # x2=58721  x1_bytes(dec)=[39, -51, 54]  x1=0x0036CD27
    addi x2, x2, 1

    # addr 58722: bytes [-33, 39, 49] (top byte 0)
    lui  x1, 786
    addi x1, x1, 2015
    sw   x1, 0(x2)    # x2=58722  x1_bytes(dec)=[-33, 39, 49]  x1=0x003127DF
    addi x2, x2, 1

    # addr 58723: bytes [3, 9, -51] (top byte 0)
    lui  x1, 3281
    addi x1, x1, -1789
    sw   x1, 0(x2)    # x2=58723  x1_bytes(dec)=[3, 9, -51]  x1=0x00CD0903
    addi x2, x2, 1

    # addr 58724: bytes [49, -46, -45] (top byte 0)
    lui  x1, 3389
    addi x1, x1, 561
    sw   x1, 0(x2)    # x2=58724  x1_bytes(dec)=[49, -46, -45]  x1=0x00D3D231
    addi x2, x2, 1

    # addr 58725: bytes [52, -73, -26] (top byte 0)
    lui  x1, 3691
    addi x1, x1, 1844
    sw   x1, 0(x2)    # x2=58725  x1_bytes(dec)=[52, -73, -26]  x1=0x00E6B734
    addi x2, x2, 1

    # addr 58726: bytes [-13, -11, -51] (top byte 0)
    lui  x1, 3295
    addi x1, x1, 1523
    sw   x1, 0(x2)    # x2=58726  x1_bytes(dec)=[-13, -11, -51]  x1=0x00CDF5F3
    addi x2, x2, 1

    # addr 58727: bytes [-2, -31, 28] (top byte 0)
    lui  x1, 462
    addi x1, x1, 510
    sw   x1, 0(x2)    # x2=58727  x1_bytes(dec)=[-2, -31, 28]  x1=0x001CE1FE
    addi x2, x2, 1

    # addr 58728: bytes [13, -34, 66] (top byte 0)
    lui  x1, 1070
    addi x1, x1, -499
    sw   x1, 0(x2)    # x2=58728  x1_bytes(dec)=[13, -34, 66]  x1=0x0042DE0D
    addi x2, x2, 1

    # addr 58729: bytes [21, 12, -43] (top byte 0)
    lui  x1, 3409
    addi x1, x1, -1003
    sw   x1, 0(x2)    # x2=58729  x1_bytes(dec)=[21, 12, -43]  x1=0x00D50C15
    addi x2, x2, 1

    # addr 58730: bytes [-9, 24, -52] (top byte 0)
    lui  x1, 3266
    addi x1, x1, -1801
    sw   x1, 0(x2)    # x2=58730  x1_bytes(dec)=[-9, 24, -52]  x1=0x00CC18F7
    addi x2, x2, 1

    # addr 58731: bytes [-64, -86, 69] (top byte 0)
    lui  x1, 1115
    addi x1, x1, -1344
    sw   x1, 0(x2)    # x2=58731  x1_bytes(dec)=[-64, -86, 69]  x1=0x0045AAC0
    addi x2, x2, 1

    # addr 58732: bytes [47, -67, -11] (top byte 0)
    lui  x1, 3932
    addi x1, x1, -721
    sw   x1, 0(x2)    # x2=58732  x1_bytes(dec)=[47, -67, -11]  x1=0x00F5BD2F
    addi x2, x2, 1

    # addr 58733: bytes [25, 4, -45] (top byte 0)
    lui  x1, 3376
    addi x1, x1, 1049
    sw   x1, 0(x2)    # x2=58733  x1_bytes(dec)=[25, 4, -45]  x1=0x00D30419
    addi x2, x2, 1

    # addr 58734: bytes [43, 20, -52] (top byte 0)
    lui  x1, 3265
    addi x1, x1, 1067
    sw   x1, 0(x2)    # x2=58734  x1_bytes(dec)=[43, 20, -52]  x1=0x00CC142B
    addi x2, x2, 1

    # addr 58735: bytes [-25, 53, 20] (top byte 0)
    lui  x1, 323
    addi x1, x1, 1511
    sw   x1, 0(x2)    # x2=58735  x1_bytes(dec)=[-25, 53, 20]  x1=0x001435E7
    addi x2, x2, 1

    # addr 58736: bytes [-72, 30, 18] (top byte 0)
    lui  x1, 290
    addi x1, x1, -328
    sw   x1, 0(x2)    # x2=58736  x1_bytes(dec)=[-72, 30, 18]  x1=0x00121EB8
    addi x2, x2, 1

    # addr 58737: bytes [-28, -63, 61] (top byte 0)
    lui  x1, 988
    addi x1, x1, 484
    sw   x1, 0(x2)    # x2=58737  x1_bytes(dec)=[-28, -63, 61]  x1=0x003DC1E4
    addi x2, x2, 1

    # addr 58738: bytes [-62, 42, -21] (top byte 0)
    lui  x1, 3763
    addi x1, x1, -1342
    sw   x1, 0(x2)    # x2=58738  x1_bytes(dec)=[-62, 42, -21]  x1=0x00EB2AC2
    addi x2, x2, 1

    # addr 58739: bytes [-63, 48, 40] (top byte 0)
    lui  x1, 643
    addi x1, x1, 193
    sw   x1, 0(x2)    # x2=58739  x1_bytes(dec)=[-63, 48, 40]  x1=0x002830C1
    addi x2, x2, 1

    # addr 58740: bytes [23, 38, -52] (top byte 0)
    lui  x1, 3266
    addi x1, x1, 1559
    sw   x1, 0(x2)    # x2=58740  x1_bytes(dec)=[23, 38, -52]  x1=0x00CC2617
    addi x2, x2, 1

    # addr 58741: bytes [65, -41, -30] (top byte 0)
    lui  x1, 3629
    addi x1, x1, 1857
    sw   x1, 0(x2)    # x2=58741  x1_bytes(dec)=[65, -41, -30]  x1=0x00E2D741
    addi x2, x2, 1

    # addr 58742: bytes [-56, 8, 22] (top byte 0)
    lui  x1, 353
    addi x1, x1, -1848
    sw   x1, 0(x2)    # x2=58742  x1_bytes(dec)=[-56, 8, 22]  x1=0x001608C8
    addi x2, x2, 1

    # addr 58743: bytes [-64, 50, 39] (top byte 0)
    lui  x1, 627
    addi x1, x1, 704
    sw   x1, 0(x2)    # x2=58743  x1_bytes(dec)=[-64, 50, 39]  x1=0x002732C0
    addi x2, x2, 1

    # addr 58744: bytes [34, -27, 47] (top byte 0)
    lui  x1, 766
    addi x1, x1, 1314
    sw   x1, 0(x2)    # x2=58744  x1_bytes(dec)=[34, -27, 47]  x1=0x002FE522
    addi x2, x2, 1

    # addr 58745: bytes [-9, -4, 31] (top byte 0)
    lui  x1, 512
    addi x1, x1, -777
    sw   x1, 0(x2)    # x2=58745  x1_bytes(dec)=[-9, -4, 31]  x1=0x001FFCF7
    addi x2, x2, 1

    # addr 58746: bytes [-69, 40, 9] (top byte 0)
    lui  x1, 147
    addi x1, x1, -1861
    sw   x1, 0(x2)    # x2=58746  x1_bytes(dec)=[-69, 40, 9]  x1=0x000928BB
    addi x2, x2, 1

    # addr 58747: bytes [-60, 10, 11] (top byte 0)
    lui  x1, 177
    addi x1, x1, -1340
    sw   x1, 0(x2)    # x2=58747  x1_bytes(dec)=[-60, 10, 11]  x1=0x000B0AC4
    addi x2, x2, 1

    # addr 58748: bytes [30, -24, 51] (top byte 0)
    lui  x1, 831
    addi x1, x1, -2018
    sw   x1, 0(x2)    # x2=58748  x1_bytes(dec)=[30, -24, 51]  x1=0x0033E81E
    addi x2, x2, 1

    # addr 58749: bytes [-44, -9, 37] (top byte 0)
    lui  x1, 607
    addi x1, x1, 2004
    sw   x1, 0(x2)    # x2=58749  x1_bytes(dec)=[-44, -9, 37]  x1=0x0025F7D4
    addi x2, x2, 1

    # addr 58750: bytes [33, 31, -52] (top byte 0)
    lui  x1, 3266
    addi x1, x1, -223
    sw   x1, 0(x2)    # x2=58750  x1_bytes(dec)=[33, 31, -52]  x1=0x00CC1F21
    addi x2, x2, 1

    # addr 58751: bytes [40, 15, -49] (top byte 0)
    lui  x1, 3313
    addi x1, x1, -216
    sw   x1, 0(x2)    # x2=58751  x1_bytes(dec)=[40, 15, -49]  x1=0x00CF0F28
    addi x2, x2, 1

    # addr 58752: bytes [-27, -25, 56] (top byte 0)
    lui  x1, 910
    addi x1, x1, 2021
    sw   x1, 0(x2)    # x2=58752  x1_bytes(dec)=[-27, -25, 56]  x1=0x0038E7E5
    addi x2, x2, 1

    # addr 58753: bytes [-36, 8, 25] (top byte 0)
    lui  x1, 401
    addi x1, x1, -1828
    sw   x1, 0(x2)    # x2=58753  x1_bytes(dec)=[-36, 8, 25]  x1=0x001908DC
    addi x2, x2, 1

    # addr 58754: bytes [48, -55, 34] (top byte 0)
    lui  x1, 557
    addi x1, x1, -1744
    sw   x1, 0(x2)    # x2=58754  x1_bytes(dec)=[48, -55, 34]  x1=0x0022C930
    addi x2, x2, 1

    # addr 58755: bytes [-45, -14, 26] (top byte 0)
    lui  x1, 431
    addi x1, x1, 723
    sw   x1, 0(x2)    # x2=58755  x1_bytes(dec)=[-45, -14, 26]  x1=0x001AF2D3
    addi x2, x2, 1

    # addr 58756: bytes [44, -5, -31] (top byte 0)
    lui  x1, 3616
    addi x1, x1, -1236
    sw   x1, 0(x2)    # x2=58756  x1_bytes(dec)=[44, -5, -31]  x1=0x00E1FB2C
    addi x2, x2, 1

    # addr 58757: bytes [-59, 11, 12] (top byte 0)
    lui  x1, 193
    addi x1, x1, -1083
    sw   x1, 0(x2)    # x2=58757  x1_bytes(dec)=[-59, 11, 12]  x1=0x000C0BC5
    addi x2, x2, 1

    # addr 58758: bytes [42, -55, 6] (top byte 0)
    lui  x1, 109
    addi x1, x1, -1750
    sw   x1, 0(x2)    # x2=58758  x1_bytes(dec)=[42, -55, 6]  x1=0x0006C92A
    addi x2, x2, 1

    # addr 58759: bytes [-32, -18, -27] (top byte 0)
    lui  x1, 3679
    addi x1, x1, -288
    sw   x1, 0(x2)    # x2=58759  x1_bytes(dec)=[-32, -18, -27]  x1=0x00E5EEE0
    addi x2, x2, 1

    # addr 58760: bytes [9, 20, -23] (top byte 0)
    lui  x1, 3729
    addi x1, x1, 1033
    sw   x1, 0(x2)    # x2=58760  x1_bytes(dec)=[9, 20, -23]  x1=0x00E91409
    addi x2, x2, 1

    # addr 58761: bytes [20, -11, -41] (top byte 0)
    lui  x1, 3455
    addi x1, x1, 1300
    sw   x1, 0(x2)    # x2=58761  x1_bytes(dec)=[20, -11, -41]  x1=0x00D7F514
    addi x2, x2, 1

    # addr 58762: bytes [-21, 24, -33] (top byte 0)
    lui  x1, 3570
    addi x1, x1, -1813
    sw   x1, 0(x2)    # x2=58762  x1_bytes(dec)=[-21, 24, -33]  x1=0x00DF18EB
    addi x2, x2, 1

    # addr 58763: bytes [64, -24, -29] (top byte 0)
    lui  x1, 3647
    addi x1, x1, -1984
    sw   x1, 0(x2)    # x2=58763  x1_bytes(dec)=[64, -24, -29]  x1=0x00E3E840