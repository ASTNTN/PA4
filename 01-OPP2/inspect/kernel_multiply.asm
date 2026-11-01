# Disassembly of kernel_multiply from bin/PolyMult.time (01-OPP2)
# Generated: 2026-09-21T16:17:40-06:00; binary mtime: 2026-09-21 12:02:41.018899985 -0600
# Command: objdump -d --no-show-raw-insn -M intel --disassemble=kernel_multiply bin/PolyMult.time
# Build flags (Makefile): -std=gnu11 -O3 -march=native -ffast-math (no -DCHECKING, no -fopenmp)


bin/PolyMult.time:     file format elf64-x86-64


Disassembly of section .init:

Disassembly of section .plt:

Disassembly of section .text:

00000000004016a0 <kernel_multiply>:
  4016a0:	push   rbp
  4016a1:	mov    eax,esi
  4016a3:	mov    rbp,rsp
  4016a6:	push   r15
  4016a8:	push   r14
  4016aa:	mov    r14d,esi
  4016ad:	push   r13
  4016af:	mov    r13d,ecx
  4016b2:	push   r12
  4016b4:	mov    r12,rdi
  4016b7:	push   rbx
  4016b8:	mov    rbx,rdx
  4016bb:	and    rsp,0xffffffffffffffe0
  4016bf:	sub    rsp,0x20
  4016c3:	add    eax,ecx
  4016c5:	js     4016de <kernel_multiply+0x3e>
  4016c7:	cdqe   
  4016c9:	mov    rdi,r8
  4016cc:	xor    esi,esi
  4016ce:	lea    rdx,[rax*4+0x4]
  4016d6:	call   4010a0 <memset@plt>
  4016db:	mov    r8,rax
  4016de:	mov    eax,r14d
  4016e1:	or     eax,r13d
  4016e4:	js     401823 <kernel_multiply+0x183>
  4016ea:	lea    r15d,[r13+0x1]
  4016ee:	mov    edi,r14d
  4016f1:	mov    rax,r8
  4016f4:	xor    esi,esi
  4016f6:	mov    edx,r15d
  4016f9:	mov    QWORD PTR [rsp+0x18],rdi
  4016fe:	mov    r14d,r15d
  401701:	shr    edx,0x3
  401704:	and    r14d,0xfffffff8
  401708:	lea    edi,[rdx-0x1]
  40170b:	add    rdi,0x1
  40170f:	shl    rdi,0x5
  401713:	nop    DWORD PTR [rax+rax*1+0x0]
  401718:	vmovss xmm1,DWORD PTR [r12+rsi*4]
  40171e:	mov    r11d,esi
  401721:	xor    edx,edx
  401723:	vbroadcastss ymm2,xmm1
  401728:	cmp    r13d,0x6
  40172c:	jbe    401832 <kernel_multiply+0x192>
  401732:	nop    WORD PTR [rax+rax*1+0x0]
  401738:	vmovups ymm0,YMMWORD PTR [rbx+rdx*1] # ~5 cycles to load from L1 in the best case
  40173d:	vfmadd213ps ymm0,ymm2,YMMWORD PTR [rax+rdx*1] # 6 cycles until the FMA is visible to the store
  401743:	vmovups YMMWORD PTR [rax+rdx*1],ymm0 # This is only viable 6 cyces after the preceding fma
  401748:	add    rdx,0x20
  40174c:	cmp    rdx,rdi
  40174f:	jne    401738 <kernel_multiply+0x98>
  401751:	cmp    r15d,r14d
  401754:	je     401802 <kernel_multiply+0x162>
  40175a:	mov    ecx,r14d
  40175d:	mov    edx,r14d
  401760:	mov    r9d,r13d
  401763:	sub    r9d,ecx
  401766:	lea    r10d,[r9+0x1]
  40176a:	cmp    r9d,0x2
  40176e:	jbe    40179a <kernel_multiply+0xfa>
  401770:	lea    r9,[rsi+rcx*1]
  401774:	vshufps xmm0,xmm1,xmm1,0x0
  401779:	lea    r9,[r8+r9*4]
  40177d:	vmovups xmm3,XMMWORD PTR [r9]
  401782:	vfmadd132ps xmm0,xmm3,XMMWORD PTR [rbx+rcx*4]
  401788:	mov    ecx,r10d
  40178b:	and    ecx,0xfffffffc
  40178e:	add    edx,ecx
  401790:	vmovups XMMWORD PTR [r9],xmm0
  401795:	cmp    r10d,ecx
  401798:	je     401802 <kernel_multiply+0x162>
  40179a:	lea    ecx,[r11+rdx*1]
  40179e:	movsxd r9,edx
  4017a1:	movsxd rcx,ecx
  4017a4:	vmovss xmm0,DWORD PTR [rbx+r9*4]
  4017aa:	lea    r10,[r9*4+0x0]
  4017b2:	lea    rcx,[r8+rcx*4]
  4017b6:	vfmadd213ss xmm0,xmm1,DWORD PTR [rcx]
  4017bb:	vmovss DWORD PTR [rcx],xmm0
  4017bf:	lea    ecx,[rdx+0x1]
  4017c2:	cmp    r13d,ecx
  4017c5:	jl     401802 <kernel_multiply+0x162>
  4017c7:	add    ecx,r11d
  4017ca:	vmovss xmm0,DWORD PTR [rbx+r10*1+0x4]
  4017d1:	add    edx,0x2
  4017d4:	movsxd rcx,ecx
  4017d7:	lea    rcx,[r8+rcx*4]
  4017db:	vfmadd213ss xmm0,xmm1,DWORD PTR [rcx]
  4017e0:	vmovss DWORD PTR [rcx],xmm0
  4017e4:	cmp    r13d,edx
  4017e7:	jl     401802 <kernel_multiply+0x162>
  4017e9:	add    edx,r11d
  4017ec:	movsxd rdx,edx
  4017ef:	lea    rdx,[r8+rdx*4]
  4017f3:	vmovss xmm4,DWORD PTR [rdx]
  4017f7:	vfmadd132ss xmm1,xmm4,DWORD PTR [rbx+r10*1+0x8]
  4017fe:	vmovss DWORD PTR [rdx],xmm1
  401802:	lea    rdx,[rsi+0x1]
  401806:	add    rax,0x4
  40180a:	cmp    rsi,QWORD PTR [rsp+0x18]
  40180f:	je     401820 <kernel_multiply+0x180>
  401811:	mov    rsi,rdx
  401814:	jmp    401718 <kernel_multiply+0x78>
  401819:	nop    DWORD PTR [rax+0x0]
  401820:	vzeroupper 
  401823:	lea    rsp,[rbp-0x28]
  401827:	pop    rbx
  401828:	pop    r12
  40182a:	pop    r13
  40182c:	pop    r14
  40182e:	pop    r15
  401830:	pop    rbp
  401831:	ret    
  401832:	xor    ecx,ecx
  401834:	xor    edx,edx
  401836:	jmp    401760 <kernel_multiply+0xc0>

Disassembly of section .fini:
