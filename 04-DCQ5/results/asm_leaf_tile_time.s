
04-DCQ5/bin/PolyMult.time:     file format elf64-x86-64


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
  4016c0:	mov    ebx,ecx
  4016c2:	and    rsp,0xffffffffffffffe0
  4016c6:	sub    rsp,0xa8
  4016cd:	mov    DWORD PTR [rsp-0x54],ecx
  4016d1:	mov    QWORD PTR [rsp-0x48],rdi
  4016d6:	imul   rax,QWORD PTR [r8+0x10]
  4016db:	vpbroadcastq ymm4,QWORD PTR [r8+0x8]
  4016e1:	mov    DWORD PTR [rsp-0x1c],esi
  4016e5:	vpbroadcastq ymm5,QWORD PTR [r8]
  4016ea:	mov    QWORD PTR [rsp-0x50],rdx
  4016ef:	vpsrlq ymm1,ymm4,0x20
  4016f4:	add    rax,0xb
  4016f8:	vmovq  xmm6,rax
  4016fd:	lea    eax,[rbx+0x10]
  401700:	vpbroadcastq ymm2,xmm6
  401705:	vmovdqa ymm6,YMMWORD PTR [rip+0x3913]        # 405020 <__dso_handle+0x18>
  40170d:	and    eax,0xfffffff8
  401710:	mov    DWORD PTR [rsp-0x3c],eax
  401714:	vpsrlq ymm3,ymm6,0x20
  401719:	vpmuludq ymm1,ymm1,ymm6
  40171d:	vpmuludq ymm3,ymm3,ymm4
  401721:	vpmuludq ymm0,ymm4,ymm6
  401725:	vpaddq ymm1,ymm1,ymm3
  401729:	vpsllq ymm1,ymm1,0x20
  40172e:	vpaddq ymm0,ymm0,ymm1
  401732:	vpaddq ymm1,ymm0,YMMWORD PTR [rip+0x3906]        # 405040 <__dso_handle+0x38>
  40173a:	vpaddq ymm0,ymm0,YMMWORD PTR [rip+0x391e]        # 405060 <__dso_handle+0x58>
  401742:	vpaddq ymm1,ymm1,ymm2
  401746:	vpaddq ymm0,ymm0,ymm2
  40174a:	vpsllq ymm1,ymm1,0x2
  40174f:	vpsllq ymm0,ymm0,0x2
  401754:	vpaddq ymm1,ymm1,ymm5
  401758:	vpaddq ymm0,ymm0,ymm5
  40175c:	vmovq  r15,xmm1
  401761:	vpextrq r8,xmm1,0x1
  401767:	vmovq  rcx,xmm0
  40176c:	vextracti128 xmm1,ymm1,0x1
  401772:	vpextrq r12,xmm0,0x1
  401778:	vextracti128 xmm0,ymm0,0x1
  40177e:	vmovq  r10,xmm1
  401783:	vpextrq r14,xmm1,0x1
  401789:	vpextrq r9,xmm0,0x1
  40178f:	cmp    esi,0x9
  401792:	jle    402140 <leaf_tile+0xa90>
  401798:	mov    QWORD PTR [rsp+0x98],rcx
  4017a0:	xor    ebx,ebx
  4017a2:	mov    r13,rdi
  4017a5:	vmovq  QWORD PTR [rsp+0xa0],xmm0
  4017ae:	xchg   ax,ax
  4017b0:	mov    eax,DWORD PTR [rbp+0x18]
  4017b3:	mov    edx,DWORD PTR [rsp-0x3c]
  4017b7:	mov    DWORD PTR [rsp-0x20],ebx
  4017bb:	vmovss xmm5,DWORD PTR [r13+0x10]
  4017c1:	vmovss xmm3,DWORD PTR [r13+0x14]
  4017c7:	mov    DWORD PTR [rsp-0x38],ebx
  4017cb:	sub    eax,ebx
  4017cd:	vmovss xmm4,DWORD PTR [r13+0x18]
  4017d3:	vmovss xmm2,DWORD PTR [r13+0x1c]
  4017d9:	cmp    eax,edx
  4017db:	vmovss xmm1,DWORD PTR [r13+0x20]
  4017e1:	vmovss xmm0,DWORD PTR [r13+0x24]
  4017e7:	vmovss DWORD PTR [rsp+0x94],xmm5
  4017f0:	cmovg  eax,edx
  4017f3:	vmovss xmm15,DWORD PTR [r13+0x0]
  4017f9:	vmovss xmm14,DWORD PTR [r13+0x4]
  4017ff:	vmovss DWORD PTR [rsp+0x90],xmm3
  401808:	vmovss xmm13,DWORD PTR [r13+0x8]
  40180e:	vmovss xmm12,DWORD PTR [r13+0xc]
  401814:	vmovss DWORD PTR [rsp+0x8c],xmm4
  40181d:	mov    DWORD PTR [rsp+0x7c],eax
  401821:	vmovss DWORD PTR [rsp+0x88],xmm2
  40182a:	vmovss DWORD PTR [rsp+0x84],xmm1
  401833:	vmovss DWORD PTR [rsp+0x80],xmm0
  40183c:	cmp    eax,0xf
  40183f:	jle    4020d3 <leaf_tile+0xa23>
  401845:	lea    r11d,[rax-0x10]
  401849:	mov    rdx,QWORD PTR [rbp+0x10]
  40184d:	xor    eax,eax
  40184f:	mov    rdi,QWORD PTR [rsp+0xa0]
  401857:	shr    r11d,0x4
  40185b:	vbroadcastss ymm7,xmm5
  401860:	vbroadcastss ymm6,xmm3
  401865:	mov    rcx,QWORD PTR [rsp+0x98]
  40186d:	lea    esi,[r11+0x1]
  401871:	vbroadcastss ymm5,xmm4
  401876:	lea    rdx,[rdx+rbx*4]
  40187a:	mov    r11,rsi
  40187d:	vbroadcastss ymm4,xmm2
  401882:	shl    rsi,0x6
  401886:	vbroadcastss ymm11,xmm15
  40188b:	vbroadcastss ymm10,xmm14
  401890:	vbroadcastss ymm9,xmm13
  401895:	vbroadcastss ymm8,xmm12
  40189a:	vbroadcastss ymm3,xmm1
  40189f:	vbroadcastss ymm2,xmm0
  4018a4:	nop    DWORD PTR [rax+0x0]
  4018a8:	vmovups ymm1,YMMWORD PTR [r15+rax*1]
  4018ae:	vmovups ymm0,YMMWORD PTR [r15+rax*1+0x20]
  4018b5:	add    rdx,0x40
  4018b9:	vfmadd213ps ymm1,ymm11,YMMWORD PTR [rdx-0x40]
  4018bf:	vfmadd213ps ymm0,ymm11,YMMWORD PTR [rdx-0x20]
  4018c5:	vfmadd231ps ymm1,ymm10,YMMWORD PTR [r8+rax*1]
  4018cb:	vfmadd231ps ymm0,ymm10,YMMWORD PTR [r8+rax*1+0x20]
  4018d2:	vfmadd231ps ymm1,ymm9,YMMWORD PTR [r10+rax*1]
  4018d8:	vfmadd231ps ymm0,ymm9,YMMWORD PTR [r10+rax*1+0x20]
  4018df:	vfmadd231ps ymm1,ymm8,YMMWORD PTR [r14+rax*1]
  4018e5:	vfmadd231ps ymm0,ymm8,YMMWORD PTR [r14+rax*1+0x20]
  4018ec:	vfmadd231ps ymm1,ymm7,YMMWORD PTR [rcx+rax*1]
  4018f2:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [rcx+rax*1+0x20]
  4018f9:	vfmadd231ps ymm1,ymm6,YMMWORD PTR [r12+rax*1]
  4018ff:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [r12+rax*1+0x20]
  401906:	vfmadd231ps ymm1,ymm5,YMMWORD PTR [rdi+rax*1]
  40190c:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rdi+rax*1+0x20]
  401913:	vfmadd231ps ymm1,ymm4,YMMWORD PTR [r9+rax*1]
  401919:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [r9+rax*1+0x20]
  401920:	vfmadd231ps ymm1,ymm3,YMMWORD PTR [r15+rax*1-0x20]
  401927:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [r15+rax*1]
  40192d:	vfmadd231ps ymm1,ymm2,YMMWORD PTR [r8+rax*1-0x20]
  401934:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [r8+rax*1]
  40193a:	add    rax,0x40
  40193e:	vmovups YMMWORD PTR [rdx-0x40],ymm1
  401943:	vmovups YMMWORD PTR [rdx-0x20],ymm0
  401948:	cmp    rax,rsi
  40194b:	jne    4018a8 <leaf_tile+0x1f8>
  401951:	mov    QWORD PTR [rsp+0xa0],rdi
  401959:	shl    r11d,0x4
  40195d:	mov    QWORD PTR [rsp+0x98],rcx
  401965:	cmp    DWORD PTR [rsp+0x7c],r11d
  40196a:	jle    401f4f <leaf_tile+0x89f>
  401970:	mov    esi,DWORD PTR [rsp+0x7c]
  401974:	sub    esi,r11d
  401977:	lea    eax,[rsi-0x1]
  40197a:	mov    DWORD PTR [rsp+0x78],esi
  40197e:	cmp    eax,0x6
  401981:	jbe    4020e5 <leaf_tile+0xa35>
  401987:	shr    esi,0x3
  40198a:	mov    rdx,QWORD PTR [rbp+0x10]
  40198e:	vbroadcastss ymm7,DWORD PTR [rsp+0x94]
  401998:	vbroadcastss ymm1,xmm15
  40199d:	mov    edi,esi
  40199f:	mov    DWORD PTR [rsp-0x34],esi
  4019a3:	movsxd rsi,r11d
  4019a6:	vbroadcastss ymm10,xmm14
  4019ab:	lea    rax,[rsi+rbx*1]
  4019af:	shl    rsi,0x2
  4019b3:	vbroadcastss ymm6,DWORD PTR [rsp+0x90]
  4019bd:	vbroadcastss ymm5,DWORD PTR [rsp+0x8c]
  4019c7:	lea    rcx,[r10+rsi*1]
  4019cb:	lea    rax,[rdx+rax*4]
  4019cf:	vbroadcastss ymm4,DWORD PTR [rsp+0x88]
  4019d9:	vbroadcastss ymm3,DWORD PTR [rsp+0x84]
  4019e3:	mov    QWORD PTR [rsp+0x48],rcx
  4019e8:	lea    rcx,[r14+rsi*1]
  4019ec:	lea    rdx,[r8+rsi*1]
  4019f0:	vbroadcastss ymm2,DWORD PTR [rsp+0x80]
  4019fa:	mov    QWORD PTR [rsp+0x50],rcx
  4019ff:	vbroadcastss ymm9,xmm13
  401a04:	vbroadcastss ymm8,xmm12
  401a09:	mov    rcx,QWORD PTR [rsp+0x98]
  401a11:	mov    QWORD PTR [rsp-0x30],rax
  401a16:	lea    rax,[r15+rsi*1]
  401a1a:	add    rcx,rsi
  401a1d:	mov    QWORD PTR [rsp+0x58],rcx
  401a22:	lea    rcx,[r12+rsi*1]
  401a26:	mov    QWORD PTR [rsp+0x60],rcx
  401a2b:	mov    rcx,QWORD PTR [rsp+0xa0]
  401a33:	add    rcx,rsi
  401a36:	mov    QWORD PTR [rsp+0x68],rcx
  401a3b:	lea    rcx,[r9+rsi*1]
  401a3f:	sub    rsi,0x20
  401a43:	mov    QWORD PTR [rsp+0x70],rcx
  401a48:	lea    rcx,[r15+rsi*1]
  401a4c:	add    rsi,r8
  401a4f:	mov    QWORD PTR [rsp+0x38],rsi
  401a54:	mov    esi,edi
  401a56:	sub    esi,0x1
  401a59:	mov    QWORD PTR [rsp+0x40],rcx
  401a5e:	mov    edi,esi
  401a60:	cmp    esi,0x1
  401a63:	jbe    4020ef <leaf_tile+0xa3f>
  401a69:	mov    rsi,QWORD PTR [rsp-0x30]
  401a6e:	mov    rcx,QWORD PTR [rsp+0x48]
  401a73:	vmovups ymm0,YMMWORD PTR [rax]
  401a77:	vmovups ymm11,YMMWORD PTR [rax+0x20]
  401a7c:	vfmadd213ps ymm0,ymm1,YMMWORD PTR [rsi]
  401a81:	add    rsi,0x40
  401a85:	vfmadd231ps ymm0,ymm10,YMMWORD PTR [rdx]
  401a8a:	vfmadd231ps ymm0,ymm9,YMMWORD PTR [rcx]
  401a8f:	mov    rcx,QWORD PTR [rsp+0x50]
  401a94:	vfmadd231ps ymm0,ymm8,YMMWORD PTR [rcx]
  401a99:	mov    rcx,QWORD PTR [rsp+0x58]
  401a9e:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [rcx]
  401aa3:	mov    rcx,QWORD PTR [rsp+0x60]
  401aa8:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [rcx]
  401aad:	mov    rcx,QWORD PTR [rsp+0x68]
  401ab2:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rcx]
  401ab7:	mov    rcx,QWORD PTR [rsp+0x70]
  401abc:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [rcx]
  401ac1:	lea    rcx,[rax+0x20]
  401ac5:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [rax-0x20]
  401acb:	mov    QWORD PTR [rsp+0x40],rcx
  401ad0:	lea    rcx,[rdx+0x20]
  401ad4:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [rdx-0x20]
  401ada:	mov    QWORD PTR [rsp+0x38],rcx
  401adf:	mov    rcx,QWORD PTR [rsp+0x48]
  401ae4:	vmovups YMMWORD PTR [rsi-0x40],ymm0
  401ae9:	vmovaps ymm0,ymm1
  401aed:	vfmadd213ps ymm0,ymm11,YMMWORD PTR [rsi-0x20]
  401af3:	vmovaps YMMWORD PTR [rsp+0x8],ymm0
  401af9:	vmovups ymm0,YMMWORD PTR [rdx+0x20]
  401afe:	vmovaps YMMWORD PTR [rsp-0x78],ymm0
  401b04:	vfmadd213ps ymm0,ymm10,YMMWORD PTR [rsp+0x8]
  401b0b:	vfmadd231ps ymm0,ymm9,YMMWORD PTR [rcx+0x20]
  401b11:	mov    rcx,QWORD PTR [rsp+0x50]
  401b16:	vfmadd231ps ymm0,ymm8,YMMWORD PTR [rcx+0x20]
  401b1c:	mov    rcx,QWORD PTR [rsp+0x58]
  401b21:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [rcx+0x20]
  401b27:	mov    rcx,QWORD PTR [rsp+0x60]
  401b2c:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [rcx+0x20]
  401b32:	mov    rcx,QWORD PTR [rsp+0x68]
  401b37:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rcx+0x20]
  401b3d:	mov    rcx,QWORD PTR [rsp+0x70]
  401b42:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [rcx+0x20]
  401b48:	lea    rcx,[rax+0x40]
  401b4c:	mov    QWORD PTR [rsp+0x8],rcx
  401b51:	lea    rcx,[rdx+0x40]
  401b55:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [rax]
  401b5a:	mov    QWORD PTR [rsp-0x28],rcx
  401b5f:	mov    rcx,QWORD PTR [rsp+0x48]
  401b64:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [rdx]
  401b69:	add    rcx,0x40
  401b6d:	mov    QWORD PTR [rsp+0x30],rcx
  401b72:	mov    rcx,QWORD PTR [rsp+0x50]
  401b77:	add    rcx,0x40
  401b7b:	mov    QWORD PTR [rsp+0x28],rcx
  401b80:	mov    rcx,QWORD PTR [rsp+0x58]
  401b85:	vmovups YMMWORD PTR [rsi-0x20],ymm0
  401b8a:	add    rcx,0x40
  401b8e:	mov    QWORD PTR [rsp],rcx
  401b92:	mov    rcx,QWORD PTR [rsp+0x60]
  401b97:	add    rcx,0x40
  401b9b:	mov    QWORD PTR [rsp-0x8],rcx
  401ba0:	mov    rcx,QWORD PTR [rsp+0x68]
  401ba5:	add    rcx,0x40
  401ba9:	mov    QWORD PTR [rsp-0x10],rcx
  401bae:	mov    rcx,QWORD PTR [rsp+0x70]
  401bb3:	add    rcx,0x40
  401bb7:	mov    QWORD PTR [rsp-0x18],rcx
  401bbc:	cmp    edi,0x3
  401bbf:	ja     402147 <leaf_tile+0xa97>
  401bc5:	mov    eax,0x2
  401bca:	mov    rdx,QWORD PTR [rsp+0x8]
  401bcf:	mov    rcx,QWORD PTR [rsp-0x28]
  401bd4:	add    eax,0x1
  401bd7:	mov    rdi,QWORD PTR [rsp+0x38]
  401bdc:	vmovups ymm0,YMMWORD PTR [rdx]
  401be0:	mov    rdx,QWORD PTR [rsp+0x30]
  401be5:	vfmadd213ps ymm0,ymm1,YMMWORD PTR [rsi]
  401bea:	vfmadd231ps ymm0,ymm10,YMMWORD PTR [rcx]
  401bef:	vfmadd231ps ymm0,ymm9,YMMWORD PTR [rdx]
  401bf4:	mov    rdx,QWORD PTR [rsp+0x28]
  401bf9:	vfmadd231ps ymm0,ymm8,YMMWORD PTR [rdx]
  401bfe:	mov    rdx,QWORD PTR [rsp]
  401c02:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [rdx]
  401c07:	mov    rdx,QWORD PTR [rsp-0x8]
  401c0c:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [rdx]
  401c11:	mov    rdx,QWORD PTR [rsp-0x10]
  401c16:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rdx]
  401c1b:	mov    rdx,QWORD PTR [rsp-0x18]
  401c20:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [rdx]
  401c25:	mov    rdx,QWORD PTR [rsp+0x40]
  401c2a:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [rdx]
  401c2f:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [rdi]
  401c34:	vmovups YMMWORD PTR [rsi],ymm0
  401c38:	cmp    DWORD PTR [rsp-0x34],eax
  401c3c:	jbe    401cab <leaf_tile+0x5fb>
  401c3e:	mov    rdx,QWORD PTR [rsp+0x8]
  401c43:	vmovups ymm0,YMMWORD PTR [rsi+0x20]
  401c48:	vfmadd132ps ymm1,ymm0,YMMWORD PTR [rdx+0x20]
  401c4e:	mov    rdx,QWORD PTR [rsp+0x30]
  401c53:	vfmadd231ps ymm1,ymm10,YMMWORD PTR [rcx+0x20]
  401c59:	vfmadd231ps ymm1,ymm9,YMMWORD PTR [rdx+0x20]
  401c5f:	mov    rdx,QWORD PTR [rsp+0x28]
  401c64:	vfmadd231ps ymm1,ymm8,YMMWORD PTR [rdx+0x20]
  401c6a:	mov    rdx,QWORD PTR [rsp]
  401c6e:	vfmadd132ps ymm7,ymm1,YMMWORD PTR [rdx+0x20]
  401c74:	mov    rdx,QWORD PTR [rsp-0x8]
  401c79:	vfmadd132ps ymm6,ymm7,YMMWORD PTR [rdx+0x20]
  401c7f:	mov    rdx,QWORD PTR [rsp-0x10]
  401c84:	vfmadd132ps ymm5,ymm6,YMMWORD PTR [rdx+0x20]
  401c8a:	mov    rdx,QWORD PTR [rsp-0x18]
  401c8f:	vfmadd132ps ymm4,ymm5,YMMWORD PTR [rdx+0x20]
  401c95:	mov    rdx,QWORD PTR [rsp+0x40]
  401c9a:	vfmadd132ps ymm3,ymm4,YMMWORD PTR [rdx+0x20]
  401ca0:	vfmadd132ps ymm2,ymm3,YMMWORD PTR [rdi+0x20]
  401ca6:	vmovups YMMWORD PTR [rsi+0x20],ymm2
  401cab:	mov    ecx,DWORD PTR [rsp+0x78]
  401caf:	mov    eax,ecx
  401cb1:	and    eax,0xfffffff8
  401cb4:	lea    edx,[rax+r11*1]
  401cb8:	cmp    eax,ecx
  401cba:	je     401f4f <leaf_tile+0x89f>
  401cc0:	mov    esi,DWORD PTR [rsp+0x78]
  401cc4:	sub    esi,eax
  401cc6:	mov    DWORD PTR [rsp+0x70],esi
  401cca:	sub    esi,0x1
  401ccd:	cmp    esi,0x2
  401cd0:	jbe    401db5 <leaf_tile+0x705>
  401cd6:	movsxd r11,r11d
  401cd9:	mov    rcx,QWORD PTR [rbp+0x10]
  401cdd:	vshufps xmm5,xmm15,xmm15,0x0
  401ce3:	vshufps xmm4,xmm14,xmm14,0x0
  401ce9:	mov    rdi,r11
  401cec:	add    r11,rbx
  401cef:	vshufps xmm3,xmm13,xmm13,0x0
  401cf5:	vshufps xmm2,xmm12,xmm12,0x0
  401cfb:	vbroadcastss xmm1,DWORD PTR [rsp+0x94]
  401d05:	add    r11,rax
  401d08:	vbroadcastss xmm0,DWORD PTR [rsp+0x90]
  401d12:	vbroadcastss xmm6,DWORD PTR [rsp+0x8c]
  401d1c:	lea    rsi,[rcx+r11*4]
  401d20:	mov    r11,rdi
  401d23:	mov    rdi,QWORD PTR [rsp+0x98]
  401d2b:	add    r11,rax
  401d2e:	vmovups xmm11,XMMWORD PTR [rsi]
  401d32:	vbroadcastss xmm7,DWORD PTR [rsp+0x88]
  401d3c:	lea    rax,[r11*4+0x0]
  401d44:	vfmadd132ps xmm5,xmm11,XMMWORD PTR [r15+r11*4]
  401d4a:	vbroadcastss xmm8,DWORD PTR [rsp+0x84]
  401d54:	vfmadd132ps xmm4,xmm5,XMMWORD PTR [r8+rax*1]
  401d5a:	vbroadcastss xmm9,DWORD PTR [rsp+0x80]
  401d64:	vfmadd132ps xmm3,xmm4,XMMWORD PTR [r10+rax*1]
  401d6a:	vfmadd132ps xmm2,xmm3,XMMWORD PTR [r14+rax*1]
  401d70:	vfmadd132ps xmm1,xmm2,XMMWORD PTR [rdi+rax*1]
  401d76:	mov    rdi,QWORD PTR [rsp+0xa0]
  401d7e:	vfmadd132ps xmm0,xmm1,XMMWORD PTR [r12+rax*1]
  401d84:	vfmadd132ps xmm6,xmm0,XMMWORD PTR [rdi+rax*1]
  401d8a:	vfmadd132ps xmm7,xmm6,XMMWORD PTR [r9+rax*1]
  401d90:	vfmadd132ps xmm8,xmm7,XMMWORD PTR [r15+rax*1-0x20]
  401d97:	vfmadd132ps xmm9,xmm8,XMMWORD PTR [r8+rax*1-0x20]
  401d9e:	vmovups XMMWORD PTR [rsi],xmm9
  401da2:	mov    esi,DWORD PTR [rsp+0x70]
  401da6:	mov    eax,esi
  401da8:	and    eax,0xfffffffc
  401dab:	add    edx,eax
  401dad:	cmp    eax,esi
  401daf:	je     401f4f <leaf_tile+0x89f>
  401db5:	mov    ecx,DWORD PTR [rsp-0x38]
  401db9:	mov    rsi,QWORD PTR [rbp+0x10]
  401dbd:	mov    rdi,QWORD PTR [rsp+0x98]
  401dc5:	vmovss xmm6,DWORD PTR [rsp+0x94]
  401dce:	vmovss xmm5,DWORD PTR [rsp+0x90]
  401dd7:	lea    eax,[rcx+rdx*1]
  401dda:	vmovss xmm7,DWORD PTR [rsp+0x8c]
  401de3:	vmovss xmm3,DWORD PTR [rsp+0x88]
  401dec:	cdqe   
  401dee:	vmovss xmm4,DWORD PTR [rsp+0x84]
  401df7:	vmovss xmm2,DWORD PTR [rsp+0x80]
  401e00:	lea    r11,[rsi+rax*4]
  401e04:	movsxd rsi,edx
  401e07:	vmovss xmm0,DWORD PTR [r15+rsi*4]
  401e0d:	vfmadd213ss xmm0,xmm15,DWORD PTR [r11]
  401e12:	lea    rax,[rsi*4+0x0]
  401e1a:	vfmadd231ss xmm0,xmm14,DWORD PTR [r8+rsi*4]
  401e20:	vfmadd231ss xmm0,xmm13,DWORD PTR [r10+rsi*4]
  401e26:	vfmadd231ss xmm0,xmm12,DWORD PTR [r14+rsi*4]
  401e2c:	vfmadd231ss xmm0,xmm6,DWORD PTR [rdi+rsi*4]
  401e32:	mov    rdi,QWORD PTR [rsp+0xa0]
  401e3a:	vfmadd231ss xmm0,xmm5,DWORD PTR [r12+rsi*4]
  401e40:	vfmadd231ss xmm0,xmm7,DWORD PTR [rdi+rsi*4]
  401e46:	vfmadd231ss xmm0,xmm3,DWORD PTR [r9+rsi*4]
  401e4c:	vfmadd231ss xmm0,xmm4,DWORD PTR [r15+rsi*4-0x20]
  401e53:	vfmadd231ss xmm0,xmm2,DWORD PTR [r8+rsi*4-0x20]
  401e5a:	lea    esi,[rdx+0x1]
  401e5d:	vmovss DWORD PTR [r11],xmm0
  401e62:	mov    r11d,DWORD PTR [rsp+0x7c]
  401e67:	cmp    r11d,esi
  401e6a:	jle    401f4f <leaf_tile+0x89f>
  401e70:	mov    rdi,QWORD PTR [rbp+0x10]
  401e74:	add    esi,ecx
  401e76:	vmovss xmm0,DWORD PTR [r15+rax*1+0x4]
  401e7d:	add    edx,0x2
  401e80:	movsxd rsi,esi
  401e83:	lea    rsi,[rdi+rsi*4]
  401e87:	mov    rdi,QWORD PTR [rsp+0x98]
  401e8f:	vfmadd213ss xmm0,xmm15,DWORD PTR [rsi]
  401e94:	vfmadd231ss xmm0,xmm14,DWORD PTR [r8+rax*1+0x4]
  401e9b:	vfmadd231ss xmm0,xmm13,DWORD PTR [r10+rax*1+0x4]
  401ea2:	vfmadd231ss xmm0,xmm12,DWORD PTR [r14+rax*1+0x4]
  401ea9:	vfmadd231ss xmm0,xmm6,DWORD PTR [rdi+rax*1+0x4]
  401eb0:	mov    rdi,QWORD PTR [rsp+0xa0]
  401eb8:	vfmadd231ss xmm0,xmm5,DWORD PTR [r12+rax*1+0x4]
  401ebf:	vfmadd231ss xmm0,xmm7,DWORD PTR [rdi+rax*1+0x4]
  401ec6:	vfmadd231ss xmm0,xmm3,DWORD PTR [r9+rax*1+0x4]
  401ecd:	vfmadd231ss xmm0,xmm4,DWORD PTR [r15+rax*1-0x1c]
  401ed4:	vfmadd231ss xmm0,xmm2,DWORD PTR [r8+rax*1-0x1c]
  401edb:	vmovss DWORD PTR [rsi],xmm0
  401edf:	cmp    r11d,edx
  401ee2:	jle    401f4f <leaf_tile+0x89f>
  401ee4:	mov    rdi,QWORD PTR [rbp+0x10]
  401ee8:	add    edx,ecx
  401eea:	mov    rsi,QWORD PTR [rsp+0x98]
  401ef2:	movsxd rdx,edx
  401ef5:	lea    rdx,[rdi+rdx*4]
  401ef9:	mov    rdi,QWORD PTR [rsp+0xa0]
  401f01:	vmovss xmm1,DWORD PTR [rdx]
  401f05:	vfmadd132ss xmm15,xmm1,DWORD PTR [r15+rax*1+0x8]
  401f0c:	vfmadd132ss xmm14,xmm15,DWORD PTR [r8+rax*1+0x8]
  401f13:	vfmadd132ss xmm13,xmm14,DWORD PTR [r10+rax*1+0x8]
  401f1a:	vfmadd132ss xmm12,xmm13,DWORD PTR [r14+rax*1+0x8]
  401f21:	vfmadd132ss xmm6,xmm12,DWORD PTR [rsi+rax*1+0x8]
  401f28:	vfmadd132ss xmm5,xmm6,DWORD PTR [r12+rax*1+0x8]
  401f2f:	vfmadd132ss xmm7,xmm5,DWORD PTR [rdi+rax*1+0x8]
  401f36:	vfmadd132ss xmm3,xmm7,DWORD PTR [r9+rax*1+0x8]
  401f3d:	vfmadd132ss xmm4,xmm3,DWORD PTR [r15+rax*1-0x18]
  401f44:	vfmadd132ss xmm2,xmm4,DWORD PTR [r8+rax*1-0x18]
  401f4b:	vmovss DWORD PTR [rdx],xmm2
  401f4f:	mov    eax,DWORD PTR [rsp-0x20]
  401f53:	add    rbx,0xa
  401f57:	add    r13,0x28
  401f5b:	lea    edx,[rbx+0x9]
  401f5e:	add    eax,0xa
  401f61:	cmp    DWORD PTR [rsp-0x1c],edx
  401f65:	jg     4017b0 <leaf_tile+0x100>
  401f6b:	cmp    DWORD PTR [rsp-0x1c],eax
  401f6f:	jle    4020c1 <leaf_tile+0xa11>
  401f75:	mov    r13d,DWORD PTR [rsp-0x54]
  401f7a:	test   r13d,r13d
  401f7d:	jle    4020c1 <leaf_tile+0xa11>
  401f83:	mov    ecx,r13d
  401f86:	mov    rbx,QWORD PTR [rbp+0x10]
  401f8a:	cdqe   
  401f8c:	mov    r11d,r13d
  401f8f:	shr    ecx,0x3
  401f92:	mov    r15,QWORD PTR [rsp-0x48]
  401f97:	mov    r12,QWORD PTR [rbp+0x10]
  401f9b:	and    r11d,0xfffffff8
  401f9f:	lea    edi,[rcx-0x1]
  401fa2:	mov    rsi,QWORD PTR [rsp-0x50]
  401fa7:	lea    rdx,[rbx+rax*4]
  401fab:	add    rdi,0x1
  401faf:	lea    ebx,[r13-0x1]
  401fb3:	shl    rdi,0x5
  401fb7:	nop    WORD PTR [rax+rax*1+0x0]
  401fc0:	vmovss xmm2,DWORD PTR [r15+rax*4]
  401fc6:	mov    r14d,eax
  401fc9:	xor    ecx,ecx
  401fcb:	vbroadcastss ymm1,xmm2
  401fd0:	cmp    ebx,0x6
  401fd3:	jbe    4020db <leaf_tile+0xa2b>
  401fd9:	nop    DWORD PTR [rax+0x0]
  401fe0:	vmovups ymm0,YMMWORD PTR [rsi+rcx*1]
  401fe5:	vfmadd213ps ymm0,ymm1,YMMWORD PTR [rdx+rcx*1]
  401feb:	vmovups YMMWORD PTR [rdx+rcx*1],ymm0
  401ff0:	add    rcx,0x20
  401ff4:	cmp    rdi,rcx
  401ff7:	jne    401fe0 <leaf_tile+0x930>
  401ff9:	cmp    r11d,r13d
  401ffc:	je     4020af <leaf_tile+0x9ff>
  402002:	mov    r8d,r11d
  402005:	mov    ecx,r11d
  402008:	mov    r9d,r13d
  40200b:	sub    r9d,r8d
  40200e:	lea    r10d,[r9-0x1]
  402012:	cmp    r10d,0x2
  402016:	jbe    402044 <leaf_tile+0x994>
  402018:	lea    r10,[rax+r8*1]
  40201c:	vshufps xmm0,xmm2,xmm2,0x0
  402021:	lea    r10,[r12+r10*4]
  402025:	vmovups xmm7,XMMWORD PTR [r10]
  40202a:	vfmadd132ps xmm0,xmm7,XMMWORD PTR [rsi+r8*4]
  402030:	mov    r8d,r9d
  402033:	and    r8d,0xfffffffc
  402037:	add    ecx,r8d
  40203a:	vmovups XMMWORD PTR [r10],xmm0
  40203f:	cmp    r8d,r9d
  402042:	je     4020af <leaf_tile+0x9ff>
  402044:	lea    r8d,[r14+rcx*1]
  402048:	movsxd r9,ecx
  40204b:	movsxd r8,r8d
  40204e:	vmovss xmm0,DWORD PTR [rsi+r9*4]
  402054:	lea    r10,[r9*4+0x0]
  40205c:	lea    r8,[r12+r8*4]
  402060:	vfmadd213ss xmm0,xmm2,DWORD PTR [r8]
  402065:	vmovss DWORD PTR [r8],xmm0
  40206a:	lea    r8d,[rcx+0x1]
  40206e:	cmp    r8d,r13d
  402071:	jge    4020af <leaf_tile+0x9ff>
  402073:	add    r8d,r14d
  402076:	vmovss xmm0,DWORD PTR [rsi+r10*1+0x4]
  40207d:	add    ecx,0x2
  402080:	movsxd r8,r8d
  402083:	lea    r8,[r12+r8*4]
  402087:	vfmadd213ss xmm0,xmm2,DWORD PTR [r8]
  40208c:	vmovss DWORD PTR [r8],xmm0
  402091:	cmp    ecx,r13d
  402094:	jge    4020af <leaf_tile+0x9ff>
  402096:	add    ecx,r14d
  402099:	movsxd rcx,ecx
  40209c:	lea    rcx,[r12+rcx*4]
  4020a0:	vmovss xmm6,DWORD PTR [rcx]
  4020a4:	vfmadd132ss xmm2,xmm6,DWORD PTR [rsi+r10*1+0x8]
  4020ab:	vmovss DWORD PTR [rcx],xmm2
  4020af:	add    rax,0x1
  4020b3:	add    rdx,0x4
  4020b7:	cmp    DWORD PTR [rsp-0x1c],eax
  4020bb:	jg     401fc0 <leaf_tile+0x910>
  4020c1:	vzeroupper 
  4020c4:	lea    rsp,[rbp-0x28]
  4020c8:	pop    rbx
  4020c9:	pop    r12
  4020cb:	pop    r13
  4020cd:	pop    r14
  4020cf:	pop    r15
  4020d1:	pop    rbp
  4020d2:	ret    
  4020d3:	xor    r11d,r11d
  4020d6:	jmp    401965 <leaf_tile+0x2b5>
  4020db:	xor    r8d,r8d
  4020de:	xor    ecx,ecx
  4020e0:	jmp    402008 <leaf_tile+0x958>
  4020e5:	mov    edx,r11d
  4020e8:	xor    eax,eax
  4020ea:	jmp    401cc0 <leaf_tile+0x610>
  4020ef:	mov    rdi,QWORD PTR [rsp+0x70]
  4020f4:	mov    rsi,QWORD PTR [rsp-0x30]
  4020f9:	mov    QWORD PTR [rsp+0x8],rax
  4020fe:	xor    eax,eax
  402100:	mov    QWORD PTR [rsp-0x28],rdx
  402105:	mov    QWORD PTR [rsp-0x18],rdi
  40210a:	mov    rdi,QWORD PTR [rsp+0x68]
  40210f:	mov    QWORD PTR [rsp-0x10],rdi
  402114:	mov    rdi,QWORD PTR [rsp+0x60]
  402119:	mov    QWORD PTR [rsp-0x8],rdi
  40211e:	mov    rdi,QWORD PTR [rsp+0x58]
  402123:	mov    QWORD PTR [rsp],rdi
  402127:	mov    rdi,QWORD PTR [rsp+0x50]
  40212c:	mov    QWORD PTR [rsp+0x28],rdi
  402131:	mov    rdi,QWORD PTR [rsp+0x48]
  402136:	mov    QWORD PTR [rsp+0x30],rdi
  40213b:	jmp    401bca <leaf_tile+0x51a>
  402140:	xor    eax,eax
  402142:	jmp    401f6b <leaf_tile+0x8bb>
  402147:	mov    rdi,QWORD PTR [rsp-0x30]
  40214c:	vmovups ymm0,YMMWORD PTR [rax+0x40]
  402151:	mov    rsi,QWORD PTR [rsp+0x48]
  402156:	mov    rcx,QWORD PTR [rsp+0x50]
  40215b:	vfmadd213ps ymm0,ymm1,YMMWORD PTR [rdi+0x40]
  402161:	vfmadd231ps ymm0,ymm10,YMMWORD PTR [rdx+0x40]
  402167:	vfmadd231ps ymm0,ymm9,YMMWORD PTR [rsi+0x40]
  40216d:	vfmadd231ps ymm0,ymm8,YMMWORD PTR [rcx+0x40]
  402173:	mov    rcx,QWORD PTR [rsp+0x58]
  402178:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [rcx+0x40]
  40217e:	mov    rcx,QWORD PTR [rsp+0x60]
  402183:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [rcx+0x40]
  402189:	mov    rcx,QWORD PTR [rsp+0x68]
  40218e:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rcx+0x40]
  402194:	mov    rcx,QWORD PTR [rsp+0x70]
  402199:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [rcx+0x40]
  40219f:	lea    rcx,[rax+0x60]
  4021a3:	sub    rax,0xffffffffffffff80
  4021a7:	mov    QWORD PTR [rsp+0x40],rcx
  4021ac:	lea    rcx,[rdx+0x60]
  4021b0:	mov    QWORD PTR [rsp+0x38],rcx
  4021b5:	mov    rcx,rsi
  4021b8:	vfmadd231ps ymm0,ymm3,ymm11
  4021bd:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [rsp-0x78]
  4021c4:	vmovups YMMWORD PTR [rdi+0x40],ymm0
  4021c9:	vmovups ymm0,YMMWORD PTR [rax-0x20]
  4021ce:	vfmadd213ps ymm0,ymm1,YMMWORD PTR [rdi+0x60]
  4021d4:	vfmadd231ps ymm0,ymm10,YMMWORD PTR [rdx+0x60]
  4021da:	vfmadd231ps ymm0,ymm9,YMMWORD PTR [rsi+0x60]
  4021e0:	mov    rsi,QWORD PTR [rsp+0x50]
  4021e5:	vfmadd231ps ymm0,ymm8,YMMWORD PTR [rsi+0x60]
  4021eb:	mov    rsi,QWORD PTR [rsp+0x58]
  4021f0:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [rsi+0x60]
  4021f6:	mov    rsi,QWORD PTR [rsp+0x60]
  4021fb:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [rsi+0x60]
  402201:	mov    rsi,QWORD PTR [rsp+0x68]
  402206:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rsi+0x60]
  40220c:	mov    rsi,QWORD PTR [rsp+0x70]
  402211:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [rsi+0x60]
  402217:	lea    rsi,[rdi+0x80]
  40221e:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [rax-0x40]
  402224:	mov    QWORD PTR [rsp+0x8],rax
  402229:	lea    rax,[rdx+0x80]
  402230:	mov    QWORD PTR [rsp-0x28],rax
  402235:	lea    rax,[rcx+0x80]
  40223c:	mov    rcx,QWORD PTR [rsp+0x50]
  402241:	mov    QWORD PTR [rsp+0x30],rax
  402246:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [rdx+0x40]
  40224c:	lea    rax,[rcx+0x80]
  402253:	mov    rcx,QWORD PTR [rsp+0x58]
  402258:	mov    QWORD PTR [rsp+0x28],rax
  40225d:	lea    rax,[rcx+0x80]
  402264:	mov    rcx,QWORD PTR [rsp+0x60]
  402269:	mov    QWORD PTR [rsp],rax
  40226d:	lea    rax,[rcx+0x80]
  402274:	mov    rcx,QWORD PTR [rsp+0x68]
  402279:	vmovups YMMWORD PTR [rdi+0x60],ymm0
  40227e:	mov    QWORD PTR [rsp-0x8],rax
  402283:	lea    rax,[rcx+0x80]
  40228a:	mov    rcx,QWORD PTR [rsp+0x70]
  40228f:	mov    QWORD PTR [rsp-0x10],rax
  402294:	lea    rax,[rcx+0x80]
  40229b:	mov    QWORD PTR [rsp-0x18],rax
  4022a0:	mov    eax,0x4
  4022a5:	jmp    401bca <leaf_tile+0x51a>

Disassembly of section .fini:
