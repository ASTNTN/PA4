
04-DCQ4/bin/PolyMult.time:     file format elf64-x86-64


Disassembly of section .init:

Disassembly of section .plt:

Disassembly of section .text:

00000000004016b0 <leaf_tile>:
  4016b0:	push   rbp
  4016b1:	movsxd rax,r9d
  4016b4:	mov    rbp,rsp
  4016b7:	push   r15
  4016b9:	push   r14
  4016bb:	push   r13
  4016bd:	push   r12
  4016bf:	push   rbx
  4016c0:	mov    ebx,esi
  4016c2:	and    rsp,0xffffffffffffffe0
  4016c6:	sub    rsp,0x28
  4016ca:	mov    DWORD PTR [rsp-0x44],esi
  4016ce:	mov    QWORD PTR [rsp-0x50],rdi
  4016d3:	vpbroadcastq ymm4,QWORD PTR [r8+0x8]
  4016d9:	imul   rax,QWORD PTR [r8+0x10]
  4016de:	mov    QWORD PTR [rsp-0x58],rdx
  4016e3:	vmovdqa ymm6,YMMWORD PTR [rip+0x3935]        # 405020 <__dso_handle+0x18>
  4016eb:	vpbroadcastq ymm5,QWORD PTR [r8]
  4016f0:	mov    DWORD PTR [rsp-0x48],ecx
  4016f4:	vpsrlq ymm1,ymm4,0x20
  4016f9:	vpsrlq ymm3,ymm6,0x20
  4016fe:	vpmuludq ymm1,ymm1,ymm6
  401702:	add    rax,0x7
  401706:	vpmuludq ymm3,ymm3,ymm4
  40170a:	vpmuludq ymm0,ymm4,ymm6
  40170e:	vmovq  xmm7,rax
  401713:	vpbroadcastq ymm2,xmm7
  401718:	lea    eax,[rcx+0xe]
  40171b:	and    eax,0xfffffff8
  40171e:	mov    DWORD PTR [rsp-0x38],eax
  401722:	vpaddq ymm1,ymm1,ymm3
  401726:	vpsllq ymm1,ymm1,0x20
  40172b:	vpaddq ymm0,ymm0,ymm1
  40172f:	vpaddq ymm1,ymm0,YMMWORD PTR [rip+0x3909]        # 405040 <__dso_handle+0x38>
  401737:	vpaddq ymm0,ymm0,YMMWORD PTR [rip+0x3921]        # 405060 <__dso_handle+0x58>
  40173f:	vpaddq ymm1,ymm1,ymm2
  401743:	vpaddq ymm0,ymm0,ymm2
  401747:	vpsllq ymm1,ymm1,0x2
  40174c:	vpsllq ymm0,ymm0,0x2
  401751:	vpaddq ymm1,ymm1,ymm5
  401755:	vpaddq ymm0,ymm0,ymm5
  401759:	vmovq  r15,xmm1
  40175e:	vpextrq r9,xmm1,0x1
  401764:	vmovq  r13,xmm0
  401769:	vextracti128 xmm1,ymm1,0x1
  40176f:	vpextrq r8,xmm0,0x1
  401775:	vextracti128 xmm0,ymm0,0x1
  40177b:	vmovq  r14,xmm1
  401780:	vpextrq rsi,xmm1,0x1
  401786:	vpextrq r10,xmm0,0x1
  40178c:	cmp    ebx,0x7
  40178f:	jle    401f3d <leaf_tile+0x88d>
  401795:	lea    eax,[rbx-0x8]
  401798:	mov    QWORD PTR [rsp+0x18],rsi
  40179d:	vmovq  r12,xmm0
  4017a2:	mov    rbx,rdi
  4017a5:	mov    QWORD PTR [rsp+0x20],0x0
  4017ae:	shr    eax,0x3
  4017b1:	add    eax,0x1
  4017b4:	mov    DWORD PTR [rsp-0x5c],eax
  4017b8:	shl    rax,0x3
  4017bc:	mov    QWORD PTR [rsp-0x40],rax
  4017c1:	nop    DWORD PTR [rax+0x0]
  4017c8:	mov    rdi,QWORD PTR [rsp+0x20]
  4017cd:	mov    eax,DWORD PTR [rbp+0x18]
  4017d0:	mov    esi,DWORD PTR [rsp-0x38]
  4017d4:	vmovss xmm3,DWORD PTR [rbx+0x10]
  4017d9:	sub    eax,edi
  4017db:	vmovss xmm1,DWORD PTR [rbx+0x14]
  4017e0:	vmovss xmm2,DWORD PTR [rbx+0x18]
  4017e5:	mov    DWORD PTR [rsp-0x34],edi
  4017e9:	cmp    eax,esi
  4017eb:	vmovss xmm0,DWORD PTR [rbx+0x1c]
  4017f0:	vmovss xmm15,DWORD PTR [rbx]
  4017f4:	vmovss DWORD PTR [rsp+0x14],xmm3
  4017fa:	cmovg  eax,esi
  4017fd:	vmovss xmm14,DWORD PTR [rbx+0x4]
  401802:	vmovss xmm13,DWORD PTR [rbx+0x8]
  401807:	vmovss DWORD PTR [rsp+0x10],xmm1
  40180d:	vmovss xmm12,DWORD PTR [rbx+0xc]
  401812:	vmovss DWORD PTR [rsp+0xc],xmm2
  401818:	mov    DWORD PTR [rsp+0x4],eax
  40181c:	vmovss DWORD PTR [rsp+0x8],xmm0
  401822:	cmp    eax,0x1f
  401825:	jle    401f23 <leaf_tile+0x873>
  40182b:	mov    rsi,QWORD PTR [rbp+0x10]
  40182f:	sub    eax,0x20
  401832:	vbroadcastss ymm4,xmm3
  401837:	xor    edx,edx
  401839:	shr    eax,0x5
  40183c:	vbroadcastss ymm3,xmm1
  401841:	vbroadcastss ymm8,xmm15
  401846:	lea    rcx,[rsi+rdi*4]
  40184a:	lea    edi,[rax+0x1]
  40184d:	mov    rsi,QWORD PTR [rsp+0x18]
  401852:	vbroadcastss ymm7,xmm14
  401857:	mov    rax,rdi
  40185a:	vbroadcastss ymm6,xmm13
  40185f:	shl    rdi,0x7
  401863:	vbroadcastss ymm5,xmm12
  401868:	vbroadcastss ymm2,xmm2
  40186d:	vbroadcastss ymm1,xmm0
  401872:	nop    WORD PTR [rax+rax*1+0x0]
  401878:	vmovups ymm11,YMMWORD PTR [r15+rdx*1]
  40187e:	vfmadd213ps ymm11,ymm8,YMMWORD PTR [rcx]
  401883:	sub    rcx,0xffffffffffffff80
  401887:	vmovups ymm10,YMMWORD PTR [r15+rdx*1+0x20]
  40188e:	vmovups ymm9,YMMWORD PTR [r15+rdx*1+0x40]
  401895:	vmovups ymm0,YMMWORD PTR [r15+rdx*1+0x60]
  40189c:	vfmadd213ps ymm10,ymm8,YMMWORD PTR [rcx-0x60]
  4018a2:	vfmadd213ps ymm9,ymm8,YMMWORD PTR [rcx-0x40]
  4018a8:	vfmadd213ps ymm0,ymm8,YMMWORD PTR [rcx-0x20]
  4018ae:	vfmadd231ps ymm11,ymm7,YMMWORD PTR [r9+rdx*1]
  4018b4:	vfmadd231ps ymm10,ymm7,YMMWORD PTR [r9+rdx*1+0x20]
  4018bb:	vfmadd231ps ymm9,ymm7,YMMWORD PTR [r9+rdx*1+0x40]
  4018c2:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [r9+rdx*1+0x60]
  4018c9:	vfmadd231ps ymm11,ymm6,YMMWORD PTR [r14+rdx*1]
  4018cf:	vfmadd231ps ymm10,ymm6,YMMWORD PTR [r14+rdx*1+0x20]
  4018d6:	vfmadd231ps ymm9,ymm6,YMMWORD PTR [r14+rdx*1+0x40]
  4018dd:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [r14+rdx*1+0x60]
  4018e4:	vfmadd231ps ymm11,ymm5,YMMWORD PTR [rsi+rdx*1]
  4018ea:	vfmadd231ps ymm10,ymm5,YMMWORD PTR [rsi+rdx*1+0x20]
  4018f1:	vfmadd231ps ymm9,ymm5,YMMWORD PTR [rsi+rdx*1+0x40]
  4018f8:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rsi+rdx*1+0x60]
  4018ff:	vfmadd231ps ymm11,ymm4,YMMWORD PTR [r13+rdx*1+0x0]
  401906:	vfmadd231ps ymm10,ymm4,YMMWORD PTR [r13+rdx*1+0x20]
  40190d:	vfmadd231ps ymm9,ymm4,YMMWORD PTR [r13+rdx*1+0x40]
  401914:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [r13+rdx*1+0x60]
  40191b:	vfmadd231ps ymm11,ymm3,YMMWORD PTR [r8+rdx*1]
  401921:	vfmadd231ps ymm10,ymm3,YMMWORD PTR [r8+rdx*1+0x20]
  401928:	vfmadd231ps ymm9,ymm3,YMMWORD PTR [r8+rdx*1+0x40]
  40192f:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [r8+rdx*1+0x60]
  401936:	vfmadd231ps ymm10,ymm2,YMMWORD PTR [r12+rdx*1+0x20]
  40193d:	vfmadd231ps ymm9,ymm2,YMMWORD PTR [r12+rdx*1+0x40]
  401944:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [r12+rdx*1+0x60]
  40194b:	vfmadd231ps ymm11,ymm2,YMMWORD PTR [r12+rdx*1]
  401951:	vfmadd231ps ymm11,ymm1,YMMWORD PTR [r10+rdx*1]
  401957:	vfmadd231ps ymm10,ymm1,YMMWORD PTR [r10+rdx*1+0x20]
  40195e:	vfmadd231ps ymm9,ymm1,YMMWORD PTR [r10+rdx*1+0x40]
  401965:	vfmadd231ps ymm0,ymm1,YMMWORD PTR [r10+rdx*1+0x60]
  40196c:	sub    rdx,0xffffffffffffff80
  401970:	vmovups YMMWORD PTR [rcx-0x80],ymm11
  401975:	vmovups YMMWORD PTR [rcx-0x60],ymm10
  40197a:	vmovups YMMWORD PTR [rcx-0x40],ymm9
  40197f:	vmovups YMMWORD PTR [rcx-0x20],ymm0
  401984:	cmp    rdx,rdi
  401987:	jne    401878 <leaf_tile+0x1c8>
  40198d:	mov    QWORD PTR [rsp+0x18],rsi
  401992:	shl    eax,0x5
  401995:	cmp    DWORD PTR [rsp+0x4],eax
  401999:	jle    401da0 <leaf_tile+0x6f0>
  40199f:	mov    ecx,DWORD PTR [rsp+0x4]
  4019a3:	sub    ecx,eax
  4019a5:	lea    edx,[rcx-0x1]
  4019a8:	cmp    edx,0x6
  4019ab:	jbe    401f2a <leaf_tile+0x87a>
  4019b1:	mov    rsi,QWORD PTR [rsp+0x20]
  4019b6:	mov    edi,ecx
  4019b8:	movsxd rdx,eax
  4019bb:	vbroadcastss ymm8,xmm15
  4019c0:	shr    edi,0x3
  4019c3:	vbroadcastss ymm7,xmm14
  4019c8:	vbroadcastss ymm6,xmm13
  4019cd:	vbroadcastss ymm4,DWORD PTR [rsp+0x14]
  4019d4:	mov    DWORD PTR [rsp],edi
  4019d7:	lea    rdi,[rsi+rdx*1]
  4019db:	mov    rsi,QWORD PTR [rbp+0x10]
  4019df:	shl    rdx,0x2
  4019e3:	lea    r11,[r15+rdx*1]
  4019e7:	vbroadcastss ymm5,xmm12
  4019ec:	vbroadcastss ymm3,DWORD PTR [rsp+0x10]
  4019f3:	vbroadcastss ymm2,DWORD PTR [rsp+0xc]
  4019fa:	lea    rdi,[rsi+rdi*4]
  4019fe:	lea    rsi,[r14+rdx*1]
  401a02:	mov    QWORD PTR [rsp-0x30],r11
  401a07:	vbroadcastss ymm1,DWORD PTR [rsp+0x8]
  401a0e:	mov    QWORD PTR [rsp-0x28],rsi
  401a13:	mov    rsi,QWORD PTR [rsp+0x18]
  401a18:	lea    r11,[r9+rdx*1]
  401a1c:	add    rsi,rdx
  401a1f:	mov    QWORD PTR [rsp-0x20],rsi
  401a24:	lea    rsi,[r13+rdx*1+0x0]
  401a29:	mov    QWORD PTR [rsp-0x18],rsi
  401a2e:	lea    rsi,[r8+rdx*1]
  401a32:	mov    QWORD PTR [rsp-0x10],rsi
  401a37:	lea    rsi,[r12+rdx*1]
  401a3b:	add    rdx,r10
  401a3e:	cmp    DWORD PTR [rsp],0x1
  401a42:	mov    QWORD PTR [rsp-0x8],rsi
  401a47:	mov    rsi,QWORD PTR [rsp-0x30]
  401a4c:	vmovups ymm0,YMMWORD PTR [rsi]
  401a50:	mov    rsi,QWORD PTR [rsp-0x28]
  401a55:	vfmadd213ps ymm0,ymm8,YMMWORD PTR [rdi]
  401a5a:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [r11]
  401a5f:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [rsi]
  401a64:	mov    rsi,QWORD PTR [rsp-0x20]
  401a69:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rsi]
  401a6e:	mov    rsi,QWORD PTR [rsp-0x18]
  401a73:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [rsi]
  401a78:	mov    rsi,QWORD PTR [rsp-0x10]
  401a7d:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [rsi]
  401a82:	mov    rsi,QWORD PTR [rsp-0x8]
  401a87:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [rsi]
  401a8c:	vfmadd231ps ymm0,ymm1,YMMWORD PTR [rdx]
  401a91:	vmovups YMMWORD PTR [rdi],ymm0
  401a95:	je     401bb3 <leaf_tile+0x503>
  401a9b:	mov    rsi,QWORD PTR [rsp-0x30]
  401aa0:	cmp    DWORD PTR [rsp],0x2
  401aa4:	vmovups ymm0,YMMWORD PTR [rsi+0x20]
  401aa9:	mov    rsi,QWORD PTR [rsp-0x28]
  401aae:	vfmadd213ps ymm0,ymm8,YMMWORD PTR [rdi+0x20]
  401ab4:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [r11+0x20]
  401aba:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [rsi+0x20]
  401ac0:	mov    rsi,QWORD PTR [rsp-0x20]
  401ac5:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rsi+0x20]
  401acb:	mov    rsi,QWORD PTR [rsp-0x18]
  401ad0:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [rsi+0x20]
  401ad6:	mov    rsi,QWORD PTR [rsp-0x10]
  401adb:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [rsi+0x20]
  401ae1:	mov    rsi,QWORD PTR [rsp-0x8]
  401ae6:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [rsi+0x20]
  401aec:	vfmadd231ps ymm0,ymm1,YMMWORD PTR [rdx+0x20]
  401af2:	vmovups YMMWORD PTR [rdi+0x20],ymm0
  401af7:	je     401bb3 <leaf_tile+0x503>
  401afd:	mov    rsi,QWORD PTR [rsp-0x30]
  401b02:	cmp    DWORD PTR [rsp],0x3
  401b06:	vmovups ymm0,YMMWORD PTR [rsi+0x40]
  401b0b:	mov    rsi,QWORD PTR [rsp-0x28]
  401b10:	vfmadd213ps ymm0,ymm8,YMMWORD PTR [rdi+0x40]
  401b16:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [r11+0x40]
  401b1c:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [rsi+0x40]
  401b22:	mov    rsi,QWORD PTR [rsp-0x20]
  401b27:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rsi+0x40]
  401b2d:	mov    rsi,QWORD PTR [rsp-0x18]
  401b32:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [rsi+0x40]
  401b38:	mov    rsi,QWORD PTR [rsp-0x10]
  401b3d:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [rsi+0x40]
  401b43:	mov    rsi,QWORD PTR [rsp-0x8]
  401b48:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [rsi+0x40]
  401b4e:	vfmadd231ps ymm0,ymm1,YMMWORD PTR [rdx+0x40]
  401b54:	vmovups YMMWORD PTR [rdi+0x40],ymm0
  401b59:	je     401bb3 <leaf_tile+0x503>
  401b5b:	mov    rsi,QWORD PTR [rsp-0x30]
  401b60:	vmovups ymm0,YMMWORD PTR [rdi+0x60]
  401b65:	vfmadd132ps ymm8,ymm0,YMMWORD PTR [rsi+0x60]
  401b6b:	mov    rsi,QWORD PTR [rsp-0x28]
  401b70:	vfmadd132ps ymm7,ymm8,YMMWORD PTR [r11+0x60]
  401b76:	vfmadd132ps ymm6,ymm7,YMMWORD PTR [rsi+0x60]
  401b7c:	mov    rsi,QWORD PTR [rsp-0x20]
  401b81:	vfmadd132ps ymm5,ymm6,YMMWORD PTR [rsi+0x60]
  401b87:	mov    rsi,QWORD PTR [rsp-0x18]
  401b8c:	vfmadd132ps ymm4,ymm5,YMMWORD PTR [rsi+0x60]
  401b92:	mov    rsi,QWORD PTR [rsp-0x10]
  401b97:	vfmadd132ps ymm3,ymm4,YMMWORD PTR [rsi+0x60]
  401b9d:	mov    rsi,QWORD PTR [rsp-0x8]
  401ba2:	vfmadd132ps ymm2,ymm3,YMMWORD PTR [rsi+0x60]
  401ba8:	vfmadd132ps ymm1,ymm2,YMMWORD PTR [rdx+0x60]
  401bae:	vmovups YMMWORD PTR [rdi+0x60],ymm1
  401bb3:	mov    edx,ecx
  401bb5:	and    edx,0xfffffff8
  401bb8:	lea    edi,[rdx+rax*1]
  401bbb:	cmp    edx,ecx
  401bbd:	je     401da0 <leaf_tile+0x6f0>
  401bc3:	sub    ecx,edx
  401bc5:	lea    r11d,[rcx-0x1]
  401bc9:	cmp    r11d,0x2
  401bcd:	jbe    401c77 <leaf_tile+0x5c7>
  401bd3:	mov    rsi,QWORD PTR [rsp+0x20]
  401bd8:	cdqe   
  401bda:	vshufps xmm7,xmm15,xmm15,0x0
  401be0:	vshufps xmm6,xmm14,xmm14,0x0
  401be6:	vshufps xmm5,xmm13,xmm13,0x0
  401bec:	vshufps xmm4,xmm12,xmm12,0x0
  401bf2:	vbroadcastss xmm3,DWORD PTR [rsp+0x14]
  401bf9:	vbroadcastss xmm2,DWORD PTR [rsp+0x10]
  401c00:	lea    r11,[rsi+rax*1]
  401c04:	mov    rsi,QWORD PTR [rbp+0x10]
  401c08:	vbroadcastss xmm1,DWORD PTR [rsp+0xc]
  401c0f:	add    r11,rdx
  401c12:	add    rdx,rax
  401c15:	vbroadcastss xmm0,DWORD PTR [rsp+0x8]
  401c1c:	lea    r11,[rsi+r11*4]
  401c20:	lea    rax,[rdx*4+0x0]
  401c28:	mov    rsi,QWORD PTR [rsp+0x18]
  401c2d:	vmovups xmm8,XMMWORD PTR [r11]
  401c32:	vfmadd132ps xmm7,xmm8,XMMWORD PTR [r15+rdx*4]
  401c38:	vfmadd132ps xmm6,xmm7,XMMWORD PTR [r9+rax*1]
  401c3e:	vfmadd132ps xmm5,xmm6,XMMWORD PTR [r14+rax*1]
  401c44:	vfmadd132ps xmm4,xmm5,XMMWORD PTR [rsi+rax*1]
  401c4a:	vfmadd132ps xmm3,xmm4,XMMWORD PTR [r13+rax*1+0x0]
  401c51:	vfmadd132ps xmm2,xmm3,XMMWORD PTR [r8+rax*1]
  401c57:	vfmadd132ps xmm1,xmm2,XMMWORD PTR [r12+rax*1]
  401c5d:	vfmadd132ps xmm0,xmm1,XMMWORD PTR [r10+rax*1]
  401c63:	mov    eax,ecx
  401c65:	and    eax,0xfffffffc
  401c68:	add    edi,eax
  401c6a:	vmovups XMMWORD PTR [r11],xmm0
  401c6f:	cmp    eax,ecx
  401c71:	je     401da0 <leaf_tile+0x6f0>
  401c77:	mov    esi,DWORD PTR [rsp-0x34]
  401c7b:	mov    rcx,QWORD PTR [rbp+0x10]
  401c7f:	movsxd rdx,edi
  401c82:	vmovss xmm0,DWORD PTR [r15+rdx*4]
  401c88:	mov    r11,QWORD PTR [rsp+0x18]
  401c8d:	lea    eax,[rsi+rdi*1]
  401c90:	vmovss xmm7,DWORD PTR [rsp+0x14]
  401c96:	vmovss xmm5,DWORD PTR [rsp+0x10]
  401c9c:	cdqe   
  401c9e:	vmovss xmm4,DWORD PTR [rsp+0xc]
  401ca4:	vmovss xmm6,DWORD PTR [rsp+0x8]
  401caa:	lea    rcx,[rcx+rax*4]
  401cae:	lea    rax,[rdx*4+0x0]
  401cb6:	vfmadd213ss xmm0,xmm15,DWORD PTR [rcx]
  401cbb:	vfmadd231ss xmm0,xmm14,DWORD PTR [r9+rdx*4]
  401cc1:	vfmadd231ss xmm0,xmm13,DWORD PTR [r14+rdx*4]
  401cc7:	vfmadd231ss xmm0,xmm12,DWORD PTR [r11+rdx*4]
  401ccd:	vfmadd231ss xmm0,xmm7,DWORD PTR [r13+rdx*4+0x0]
  401cd4:	vfmadd231ss xmm0,xmm5,DWORD PTR [r8+rdx*4]
  401cda:	vfmadd231ss xmm0,xmm4,DWORD PTR [r12+rdx*4]
  401ce0:	vfmadd231ss xmm0,xmm6,DWORD PTR [r10+rdx*4]
  401ce6:	lea    edx,[rdi+0x1]
  401ce9:	vmovss DWORD PTR [rcx],xmm0
  401ced:	mov    ecx,DWORD PTR [rsp+0x4]
  401cf1:	cmp    edx,ecx
  401cf3:	jge    401da0 <leaf_tile+0x6f0>
  401cf9:	mov    r11,QWORD PTR [rbp+0x10]
  401cfd:	add    edx,esi
  401cff:	vmovss xmm0,DWORD PTR [r15+rax*1+0x4]
  401d06:	add    edi,0x2
  401d09:	movsxd rdx,edx
  401d0c:	lea    rdx,[r11+rdx*4]
  401d10:	mov    r11,QWORD PTR [rsp+0x18]
  401d15:	vfmadd213ss xmm0,xmm15,DWORD PTR [rdx]
  401d1a:	vfmadd231ss xmm0,xmm14,DWORD PTR [r9+rax*1+0x4]
  401d21:	vfmadd231ss xmm0,xmm13,DWORD PTR [r14+rax*1+0x4]
  401d28:	vfmadd231ss xmm0,xmm12,DWORD PTR [r11+rax*1+0x4]
  401d2f:	vfmadd231ss xmm0,xmm7,DWORD PTR [r13+rax*1+0x4]
  401d36:	vfmadd231ss xmm0,xmm5,DWORD PTR [r8+rax*1+0x4]
  401d3d:	vfmadd231ss xmm0,xmm4,DWORD PTR [r12+rax*1+0x4]
  401d44:	vfmadd231ss xmm0,xmm6,DWORD PTR [r10+rax*1+0x4]
  401d4b:	vmovss DWORD PTR [rdx],xmm0
  401d4f:	cmp    edi,ecx
  401d51:	jge    401da0 <leaf_tile+0x6f0>
  401d53:	add    edi,esi
  401d55:	movsxd rdx,edi
  401d58:	mov    rdi,QWORD PTR [rbp+0x10]
  401d5c:	lea    rdx,[rdi+rdx*4]
  401d60:	vmovss xmm3,DWORD PTR [rdx]
  401d64:	vfmadd132ss xmm15,xmm3,DWORD PTR [r15+rax*1+0x8]
  401d6b:	vfmadd132ss xmm14,xmm15,DWORD PTR [r9+rax*1+0x8]
  401d72:	vfmadd132ss xmm13,xmm14,DWORD PTR [r14+rax*1+0x8]
  401d79:	vfmadd132ss xmm12,xmm13,DWORD PTR [r11+rax*1+0x8]
  401d80:	vfmadd132ss xmm7,xmm12,DWORD PTR [r13+rax*1+0x8]
  401d87:	vfmadd132ss xmm5,xmm7,DWORD PTR [r8+rax*1+0x8]
  401d8e:	vfmadd132ss xmm4,xmm5,DWORD PTR [r12+rax*1+0x8]
  401d95:	vfmadd132ss xmm6,xmm4,DWORD PTR [r10+rax*1+0x8]
  401d9c:	vmovss DWORD PTR [rdx],xmm6
  401da0:	add    QWORD PTR [rsp+0x20],0x8
  401da6:	add    rbx,0x20
  401daa:	mov    rax,QWORD PTR [rsp+0x20]
  401daf:	cmp    rax,QWORD PTR [rsp-0x40]
  401db4:	jne    4017c8 <leaf_tile+0x118>
  401dba:	mov    esi,DWORD PTR [rsp-0x5c]
  401dbe:	shl    esi,0x3
  401dc1:	cmp    DWORD PTR [rsp-0x44],esi
  401dc5:	jle    401f11 <leaf_tile+0x861>
  401dcb:	mov    r13d,DWORD PTR [rsp-0x48]
  401dd0:	test   r13d,r13d
  401dd3:	jle    401f11 <leaf_tile+0x861>
  401dd9:	mov    edx,r13d
  401ddc:	mov    rax,QWORD PTR [rbp+0x10]
  401de0:	movsxd rsi,esi
  401de3:	mov    r11d,r13d
  401de6:	shr    edx,0x3
  401de9:	mov    r15,QWORD PTR [rsp-0x50]
  401dee:	mov    r12,QWORD PTR [rbp+0x10]
  401df2:	lea    ebx,[r13-0x1]
  401df6:	lea    edi,[rdx-0x1]
  401df9:	mov    rcx,QWORD PTR [rsp-0x58]
  401dfe:	lea    rax,[rax+rsi*4]
  401e02:	and    r11d,0xfffffff8
  401e06:	add    rdi,0x1
  401e0a:	shl    rdi,0x5
  401e0e:	xchg   ax,ax
  401e10:	vmovss xmm2,DWORD PTR [r15+rsi*4]
  401e16:	mov    r14d,esi
  401e19:	xor    edx,edx
  401e1b:	vbroadcastss ymm1,xmm2
  401e20:	cmp    ebx,0x6
  401e23:	jbe    401f33 <leaf_tile+0x883>
  401e29:	nop    DWORD PTR [rax+0x0]
  401e30:	vmovups ymm0,YMMWORD PTR [rcx+rdx*1]
  401e35:	vfmadd213ps ymm0,ymm1,YMMWORD PTR [rax+rdx*1]
  401e3b:	vmovups YMMWORD PTR [rax+rdx*1],ymm0
  401e40:	add    rdx,0x20
  401e44:	cmp    rdi,rdx
  401e47:	jne    401e30 <leaf_tile+0x780>
  401e49:	cmp    r11d,r13d
  401e4c:	je     401eff <leaf_tile+0x84f>
  401e52:	mov    r8d,r11d
  401e55:	mov    edx,r11d
  401e58:	mov    r9d,r13d
  401e5b:	sub    r9d,r8d
  401e5e:	lea    r10d,[r9-0x1]
  401e62:	cmp    r10d,0x2
  401e66:	jbe    401e94 <leaf_tile+0x7e4>
  401e68:	lea    r10,[rsi+r8*1]
  401e6c:	vshufps xmm0,xmm2,xmm2,0x0
  401e71:	lea    r10,[r12+r10*4]
  401e75:	vmovups xmm7,XMMWORD PTR [r10]
  401e7a:	vfmadd132ps xmm0,xmm7,XMMWORD PTR [rcx+r8*4]
  401e80:	mov    r8d,r9d
  401e83:	and    r8d,0xfffffffc
  401e87:	add    edx,r8d
  401e8a:	vmovups XMMWORD PTR [r10],xmm0
  401e8f:	cmp    r8d,r9d
  401e92:	je     401eff <leaf_tile+0x84f>
  401e94:	lea    r8d,[r14+rdx*1]
  401e98:	movsxd r9,edx
  401e9b:	movsxd r8,r8d
  401e9e:	vmovss xmm0,DWORD PTR [rcx+r9*4]
  401ea4:	lea    r10,[r9*4+0x0]
  401eac:	lea    r8,[r12+r8*4]
  401eb0:	vfmadd213ss xmm0,xmm2,DWORD PTR [r8]
  401eb5:	vmovss DWORD PTR [r8],xmm0
  401eba:	lea    r8d,[rdx+0x1]
  401ebe:	cmp    r13d,r8d
  401ec1:	jle    401eff <leaf_tile+0x84f>
  401ec3:	add    r8d,r14d
  401ec6:	vmovss xmm0,DWORD PTR [rcx+r10*1+0x4]
  401ecd:	add    edx,0x2
  401ed0:	movsxd r8,r8d
  401ed3:	lea    r8,[r12+r8*4]
  401ed7:	vfmadd213ss xmm0,xmm2,DWORD PTR [r8]
  401edc:	vmovss DWORD PTR [r8],xmm0
  401ee1:	cmp    edx,r13d
  401ee4:	jge    401eff <leaf_tile+0x84f>
  401ee6:	add    edx,r14d
  401ee9:	movsxd rdx,edx
  401eec:	lea    rdx,[r12+rdx*4]
  401ef0:	vmovss xmm3,DWORD PTR [rdx]
  401ef4:	vfmadd132ss xmm2,xmm3,DWORD PTR [rcx+r10*1+0x8]
  401efb:	vmovss DWORD PTR [rdx],xmm2
  401eff:	add    rsi,0x1
  401f03:	add    rax,0x4
  401f07:	cmp    DWORD PTR [rsp-0x44],esi
  401f0b:	jg     401e10 <leaf_tile+0x760>
  401f11:	vzeroupper 
  401f14:	lea    rsp,[rbp-0x28]
  401f18:	pop    rbx
  401f19:	pop    r12
  401f1b:	pop    r13
  401f1d:	pop    r14
  401f1f:	pop    r15
  401f21:	pop    rbp
  401f22:	ret    
  401f23:	xor    eax,eax
  401f25:	jmp    401995 <leaf_tile+0x2e5>
  401f2a:	mov    edi,eax
  401f2c:	xor    edx,edx
  401f2e:	jmp    401bc3 <leaf_tile+0x513>
  401f33:	xor    r8d,r8d
  401f36:	xor    edx,edx
  401f38:	jmp    401e58 <leaf_tile+0x7a8>
  401f3d:	xor    esi,esi
  401f3f:	jmp    401dc1 <leaf_tile+0x711>

Disassembly of section .fini:
