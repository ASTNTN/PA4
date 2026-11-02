
04-DCQ3/bin/PolyMult.time:     file format elf64-x86-64


Disassembly of section .init:

Disassembly of section .plt:

Disassembly of section .text:

00000000004016b0 <leaf_tile>:
  4016b0:	push   rbp
  4016b1:	movsxd rax,r9d
  4016b4:	mov    r11,rdi
  4016b7:	mov    rbp,rsp
  4016ba:	push   r15
  4016bc:	push   r14
  4016be:	push   r13
  4016c0:	push   r12
  4016c2:	push   rbx
  4016c3:	and    rsp,0xffffffffffffffe0
  4016c7:	mov    QWORD PTR [rsp-0x40],rdi
  4016cc:	mov    rdi,rdx
  4016cf:	imul   rax,QWORD PTR [r8+0x10]
  4016d4:	vpbroadcastq ymm4,QWORD PTR [r8+0x8]
  4016da:	mov    DWORD PTR [rsp-0x24],esi
  4016de:	vpbroadcastq ymm5,QWORD PTR [r8]
  4016e3:	mov    DWORD PTR [rsp-0x28],ecx
  4016e7:	vpsrlq ymm1,ymm4,0x20
  4016ec:	add    rax,0x7
  4016f0:	vmovq  xmm6,rax
  4016f5:	lea    eax,[rcx+0xe]
  4016f8:	vpbroadcastq ymm2,xmm6
  4016fd:	vmovdqa ymm6,YMMWORD PTR [rip+0x391b]        # 405020 <__dso_handle+0x18>
  401705:	and    eax,0xfffffff8
  401708:	mov    DWORD PTR [rsp-0x18],eax
  40170c:	vpsrlq ymm3,ymm6,0x20
  401711:	vpmuludq ymm1,ymm1,ymm6
  401715:	vpmuludq ymm3,ymm3,ymm4
  401719:	vpmuludq ymm0,ymm4,ymm6
  40171d:	vpaddq ymm1,ymm1,ymm3
  401721:	vpsllq ymm1,ymm1,0x20
  401726:	vpaddq ymm0,ymm0,ymm1
  40172a:	vpaddq ymm1,ymm0,YMMWORD PTR [rip+0x390e]        # 405040 <__dso_handle+0x38>
  401732:	vpaddq ymm0,ymm0,YMMWORD PTR [rip+0x3926]        # 405060 <__dso_handle+0x58>
  40173a:	vpaddq ymm1,ymm1,ymm2
  40173e:	vpaddq ymm0,ymm0,ymm2
  401742:	vpsllq ymm1,ymm1,0x2
  401747:	vpsllq ymm0,ymm0,0x2
  40174c:	vpaddq ymm1,ymm1,ymm5
  401750:	vpaddq ymm0,ymm0,ymm5
  401754:	vmovq  r14,xmm1
  401759:	vpextrq r15,xmm1,0x1
  40175f:	vmovq  r12,xmm0
  401764:	vextracti128 xmm1,ymm1,0x1
  40176a:	vpextrq r9,xmm0,0x1
  401770:	vextracti128 xmm0,ymm0,0x1
  401776:	vmovq  rbx,xmm1
  40177b:	vpextrq r10,xmm1,0x1
  401781:	vpextrq r8,xmm0,0x1
  401787:	cmp    esi,0x7
  40178a:	jle    401c26 <leaf_tile+0x576>
  401790:	lea    eax,[rsi-0x8]
  401793:	mov    QWORD PTR [rsp-0x38],rdx
  401798:	vmovq  r13,xmm0
  40179d:	shr    eax,0x3
  4017a0:	mov    QWORD PTR [rsp-0x8],r10
  4017a5:	add    eax,0x1
  4017a8:	mov    DWORD PTR [rsp-0x2c],eax
  4017ac:	shl    rax,0x3
  4017b0:	mov    QWORD PTR [rsp-0x20],rax
  4017b5:	xor    eax,eax
  4017b7:	mov    r10,rax
  4017ba:	nop    WORD PTR [rax+rax*1+0x0]
  4017c0:	mov    ecx,DWORD PTR [rbp+0x18]
  4017c3:	mov    eax,DWORD PTR [rsp-0x18]
  4017c7:	mov    DWORD PTR [rsp-0x14],r10d
  4017cc:	vmovss xmm1,DWORD PTR [r11+0x1c]
  4017d2:	vmovss xmm15,DWORD PTR [r11]
  4017d7:	sub    ecx,r10d
  4017da:	vmovss xmm14,DWORD PTR [r11+0x4]
  4017e0:	vmovss xmm13,DWORD PTR [r11+0x8]
  4017e6:	cmp    ecx,eax
  4017e8:	vmovss xmm12,DWORD PTR [r11+0xc]
  4017ee:	vmovss xmm11,DWORD PTR [r11+0x10]
  4017f4:	vmovss DWORD PTR [rsp-0x10],xmm1
  4017fa:	cmovg  ecx,eax
  4017fd:	vmovss xmm10,DWORD PTR [r11+0x14]
  401803:	vmovss xmm9,DWORD PTR [r11+0x18]
  401809:	test   ecx,ecx
  40180b:	jle    401a8d <leaf_tile+0x3dd>
  401811:	lea    eax,[rcx-0x1]
  401814:	cmp    eax,0x6
  401817:	jbe    401c0e <leaf_tile+0x55e>
  40181d:	mov    rax,QWORD PTR [rbp+0x10]
  401821:	mov    esi,ecx
  401823:	mov    rdi,QWORD PTR [rsp-0x8]
  401828:	vbroadcastss ymm8,xmm15
  40182d:	shr    esi,0x3
  401830:	vbroadcastss ymm7,xmm14
  401835:	vbroadcastss ymm6,xmm13
  40183a:	lea    rdx,[rax+r10*4]
  40183e:	vbroadcastss ymm5,xmm12
  401843:	vbroadcastss ymm4,xmm11
  401848:	shl    rsi,0x5
  40184c:	vbroadcastss ymm3,xmm10
  401851:	vbroadcastss ymm2,xmm9
  401856:	vbroadcastss ymm1,xmm1
  40185b:	xor    eax,eax
  40185d:	nop    DWORD PTR [rax]
  401860:	vmovups ymm0,YMMWORD PTR [r14+rax*1]
  401866:	vfmadd213ps ymm0,ymm8,YMMWORD PTR [rdx+rax*1]
  40186c:	vfmadd231ps ymm0,ymm7,YMMWORD PTR [r15+rax*1]
  401872:	vfmadd231ps ymm0,ymm6,YMMWORD PTR [rbx+rax*1]
  401878:	vfmadd231ps ymm0,ymm5,YMMWORD PTR [rdi+rax*1]
  40187e:	vfmadd231ps ymm0,ymm4,YMMWORD PTR [r12+rax*1]
  401884:	vfmadd231ps ymm0,ymm3,YMMWORD PTR [r9+rax*1]
  40188a:	vfmadd231ps ymm0,ymm2,YMMWORD PTR [r13+rax*1+0x0]
  401891:	vfmadd231ps ymm0,ymm1,YMMWORD PTR [r8+rax*1]
  401897:	vmovups YMMWORD PTR [rdx+rax*1],ymm0
  40189c:	add    rax,0x20
  4018a0:	cmp    rax,rsi
  4018a3:	jne    401860 <leaf_tile+0x1b0>
  4018a5:	mov    edx,ecx
  4018a7:	mov    QWORD PTR [rsp-0x8],rdi
  4018ac:	and    edx,0xfffffff8
  4018af:	mov    DWORD PTR [rsp-0xc],edx
  4018b3:	cmp    edx,ecx
  4018b5:	je     401a8d <leaf_tile+0x3dd>
  4018bb:	mov    eax,ecx
  4018bd:	sub    eax,edx
  4018bf:	mov    esi,eax
  4018c1:	sub    eax,0x1
  4018c4:	cmp    eax,0x2
  4018c7:	jbe    401964 <leaf_tile+0x2b4>
  4018cd:	mov    rdi,QWORD PTR [rbp+0x10]
  4018d1:	lea    rax,[r10+rdx*1]
  4018d5:	vshufps xmm7,xmm15,xmm15,0x0
  4018db:	vshufps xmm6,xmm14,xmm14,0x0
  4018e1:	vshufps xmm5,xmm13,xmm13,0x0
  4018e7:	vshufps xmm4,xmm12,xmm12,0x0
  4018ed:	vshufps xmm3,xmm11,xmm11,0x0
  4018f3:	vshufps xmm2,xmm10,xmm10,0x0
  4018f9:	lea    rax,[rdi+rax*4]
  4018fd:	vshufps xmm1,xmm9,xmm9,0x0
  401903:	vbroadcastss xmm0,DWORD PTR [rsp-0x10]
  40190a:	mov    rdi,rax
  40190d:	lea    rax,[rdx*4+0x0]
  401915:	vmovups xmm8,XMMWORD PTR [rdi]
  401919:	vfmadd132ps xmm7,xmm8,XMMWORD PTR [r14+rdx*4]
  40191f:	vfmadd132ps xmm6,xmm7,XMMWORD PTR [r15+rax*1]
  401925:	mov    rdx,QWORD PTR [rsp-0x8]
  40192a:	vfmadd132ps xmm5,xmm6,XMMWORD PTR [rbx+rax*1]
  401930:	vfmadd132ps xmm4,xmm5,XMMWORD PTR [rdx+rax*1]
  401936:	vfmadd132ps xmm3,xmm4,XMMWORD PTR [r12+rax*1]
  40193c:	vfmadd132ps xmm2,xmm3,XMMWORD PTR [r9+rax*1]
  401942:	vfmadd132ps xmm1,xmm2,XMMWORD PTR [r13+rax*1+0x0]
  401949:	vfmadd132ps xmm0,xmm1,XMMWORD PTR [r8+rax*1]
  40194f:	mov    eax,esi
  401951:	and    eax,0xfffffffc
  401954:	add    DWORD PTR [rsp-0xc],eax
  401958:	vmovups XMMWORD PTR [rdi],xmm0
  40195c:	cmp    esi,eax
  40195e:	je     401a8d <leaf_tile+0x3dd>
  401964:	movsxd rdx,DWORD PTR [rsp-0xc]
  401969:	mov    edi,DWORD PTR [rsp-0x14]
  40196d:	mov    rsi,QWORD PTR [rbp+0x10]
  401971:	vmovss xmm7,DWORD PTR [rsp-0x10]
  401977:	lea    eax,[rdi+rdx*1]
  40197a:	vmovss xmm0,DWORD PTR [r14+rdx*4]
  401980:	mov    rdi,QWORD PTR [rsp-0x8]
  401985:	cdqe   
  401987:	lea    rax,[rsi+rax*4]
  40198b:	mov    rsi,rax
  40198e:	lea    rax,[rdx*4+0x0]
  401996:	vfmadd213ss xmm0,xmm15,DWORD PTR [rsi]
  40199b:	vfmadd231ss xmm0,xmm14,DWORD PTR [r15+rdx*4]
  4019a1:	vfmadd231ss xmm0,xmm13,DWORD PTR [rbx+rdx*4]
  4019a7:	vfmadd231ss xmm0,xmm12,DWORD PTR [rdi+rdx*4]
  4019ad:	vfmadd231ss xmm0,xmm11,DWORD PTR [r12+rdx*4]
  4019b3:	vfmadd231ss xmm0,xmm10,DWORD PTR [r9+rdx*4]
  4019b9:	vfmadd231ss xmm0,xmm9,DWORD PTR [r13+rdx*4+0x0]
  4019c0:	vfmadd231ss xmm0,xmm7,DWORD PTR [r8+rdx*4]
  4019c6:	vmovss DWORD PTR [rsi],xmm0
  4019ca:	mov    esi,DWORD PTR [rsp-0xc]
  4019ce:	lea    edx,[rsi+0x1]
  4019d1:	cmp    ecx,edx
  4019d3:	jle    401a8d <leaf_tile+0x3dd>
  4019d9:	mov    edi,DWORD PTR [rsp-0x14]
  4019dd:	mov    rsi,QWORD PTR [rbp+0x10]
  4019e1:	vmovss xmm0,DWORD PTR [r14+rax*1+0x4]
  4019e8:	add    edx,edi
  4019ea:	movsxd rdx,edx
  4019ed:	lea    rdx,[rsi+rdx*4]
  4019f1:	mov    rsi,QWORD PTR [rsp-0x8]
  4019f6:	vfmadd213ss xmm0,xmm15,DWORD PTR [rdx]
  4019fb:	vfmadd231ss xmm0,xmm14,DWORD PTR [r15+rax*1+0x4]
  401a02:	vfmadd231ss xmm0,xmm13,DWORD PTR [rbx+rax*1+0x4]
  401a09:	vfmadd231ss xmm0,xmm12,DWORD PTR [rsi+rax*1+0x4]
  401a10:	mov    esi,DWORD PTR [rsp-0xc]
  401a14:	vfmadd231ss xmm0,xmm11,DWORD PTR [r12+rax*1+0x4]
  401a1b:	vfmadd231ss xmm0,xmm10,DWORD PTR [r9+rax*1+0x4]
  401a22:	add    esi,0x2
  401a25:	vfmadd231ss xmm0,xmm9,DWORD PTR [r13+rax*1+0x4]
  401a2c:	vfmadd231ss xmm0,xmm7,DWORD PTR [r8+rax*1+0x4]
  401a33:	vmovss DWORD PTR [rdx],xmm0
  401a37:	cmp    ecx,esi
  401a39:	jle    401a8d <leaf_tile+0x3dd>
  401a3b:	add    esi,edi
  401a3d:	mov    rdi,QWORD PTR [rbp+0x10]
  401a41:	movsxd rsi,esi
  401a44:	lea    rdx,[rdi+rsi*4]
  401a48:	mov    rdi,QWORD PTR [rsp-0x8]
  401a4d:	vmovss xmm3,DWORD PTR [rdx]
  401a51:	vfmadd132ss xmm15,xmm3,DWORD PTR [r14+rax*1+0x8]
  401a58:	vfmadd132ss xmm14,xmm15,DWORD PTR [r15+rax*1+0x8]
  401a5f:	vfmadd132ss xmm13,xmm14,DWORD PTR [rbx+rax*1+0x8]
  401a66:	vfmadd132ss xmm12,xmm13,DWORD PTR [rdi+rax*1+0x8]
  401a6d:	vfmadd132ss xmm11,xmm12,DWORD PTR [r12+rax*1+0x8]
  401a74:	vfmadd132ss xmm10,xmm11,DWORD PTR [r9+rax*1+0x8]
  401a7b:	vfmadd132ss xmm9,xmm10,DWORD PTR [r13+rax*1+0x8]
  401a82:	vfmadd132ss xmm7,xmm9,DWORD PTR [r8+rax*1+0x8]
  401a89:	vmovss DWORD PTR [rdx],xmm7
  401a8d:	add    r10,0x8
  401a91:	add    r11,0x20
  401a95:	cmp    r10,QWORD PTR [rsp-0x20]
  401a9a:	jne    4017c0 <leaf_tile+0x110>
  401aa0:	mov    esi,DWORD PTR [rsp-0x2c]
  401aa4:	mov    rdi,QWORD PTR [rsp-0x38]
  401aa9:	shl    esi,0x3
  401aac:	cmp    DWORD PTR [rsp-0x24],esi
  401ab0:	jle    401bfc <leaf_tile+0x54c>
  401ab6:	mov    r13d,DWORD PTR [rsp-0x28]
  401abb:	test   r13d,r13d
  401abe:	jle    401bfc <leaf_tile+0x54c>
  401ac4:	mov    edx,r13d
  401ac7:	mov    rax,QWORD PTR [rbp+0x10]
  401acb:	movsxd rsi,esi
  401ace:	mov    r11d,r13d
  401ad1:	shr    edx,0x3
  401ad4:	mov    r15,QWORD PTR [rsp-0x40]
  401ad9:	mov    r10,QWORD PTR [rbp+0x10]
  401add:	lea    ebx,[r13-0x1]
  401ae1:	sub    edx,0x1
  401ae4:	lea    rax,[rax+rsi*4]
  401ae8:	and    r11d,0xfffffff8
  401aec:	add    rdx,0x1
  401af0:	shl    rdx,0x5
  401af4:	mov    r12,rdx
  401af7:	nop    WORD PTR [rax+rax*1+0x0]
  401b00:	vmovss xmm1,DWORD PTR [r15+rsi*4]
  401b06:	mov    r14d,esi
  401b09:	xor    edx,edx
  401b0b:	vbroadcastss ymm2,xmm1
  401b10:	cmp    ebx,0x6
  401b13:	jbe    401c1d <leaf_tile+0x56d>
  401b19:	nop    DWORD PTR [rax+0x0]
  401b20:	vmovups ymm0,YMMWORD PTR [rdi+rdx*1]
  401b25:	vfmadd213ps ymm0,ymm2,YMMWORD PTR [rax+rdx*1]
  401b2b:	vmovups YMMWORD PTR [rax+rdx*1],ymm0
  401b30:	add    rdx,0x20
  401b34:	cmp    r12,rdx
  401b37:	jne    401b20 <leaf_tile+0x470>
  401b39:	cmp    r11d,r13d
  401b3c:	je     401bea <leaf_tile+0x53a>
  401b42:	mov    ecx,r11d
  401b45:	mov    edx,r11d
  401b48:	mov    r8d,r13d
  401b4b:	sub    r8d,ecx
  401b4e:	lea    r9d,[r8-0x1]
  401b52:	cmp    r9d,0x2
  401b56:	jbe    401b82 <leaf_tile+0x4d2>
  401b58:	lea    r9,[rsi+rcx*1]
  401b5c:	vshufps xmm0,xmm1,xmm1,0x0
  401b61:	lea    r9,[r10+r9*4]
  401b65:	vmovups xmm5,XMMWORD PTR [r9]
  401b6a:	vfmadd132ps xmm0,xmm5,XMMWORD PTR [rdi+rcx*4]
  401b70:	mov    ecx,r8d
  401b73:	and    ecx,0xfffffffc
  401b76:	add    edx,ecx
  401b78:	vmovups XMMWORD PTR [r9],xmm0
  401b7d:	cmp    ecx,r8d
  401b80:	je     401bea <leaf_tile+0x53a>
  401b82:	lea    ecx,[r14+rdx*1]
  401b86:	movsxd r8,edx
  401b89:	movsxd rcx,ecx
  401b8c:	vmovss xmm0,DWORD PTR [rdi+r8*4]
  401b92:	lea    r9,[r8*4+0x0]
  401b9a:	lea    rcx,[r10+rcx*4]
  401b9e:	vfmadd213ss xmm0,xmm1,DWORD PTR [rcx]
  401ba3:	vmovss DWORD PTR [rcx],xmm0
  401ba7:	lea    ecx,[rdx+0x1]
  401baa:	cmp    ecx,r13d
  401bad:	jge    401bea <leaf_tile+0x53a>
  401baf:	add    ecx,r14d
  401bb2:	vmovss xmm0,DWORD PTR [rdi+r9*1+0x4]
  401bb9:	add    edx,0x2
  401bbc:	movsxd rcx,ecx
  401bbf:	lea    rcx,[r10+rcx*4]
  401bc3:	vfmadd213ss xmm0,xmm1,DWORD PTR [rcx]
  401bc8:	vmovss DWORD PTR [rcx],xmm0
  401bcc:	cmp    edx,r13d
  401bcf:	jge    401bea <leaf_tile+0x53a>
  401bd1:	add    edx,r14d
  401bd4:	movsxd rdx,edx
  401bd7:	lea    rdx,[r10+rdx*4]
  401bdb:	vmovss xmm4,DWORD PTR [rdx]
  401bdf:	vfmadd132ss xmm1,xmm4,DWORD PTR [rdi+r9*1+0x8]
  401be6:	vmovss DWORD PTR [rdx],xmm1
  401bea:	add    rsi,0x1
  401bee:	add    rax,0x4
  401bf2:	cmp    DWORD PTR [rsp-0x24],esi
  401bf6:	jg     401b00 <leaf_tile+0x450>
  401bfc:	vzeroupper 
  401bff:	lea    rsp,[rbp-0x28]
  401c03:	pop    rbx
  401c04:	pop    r12
  401c06:	pop    r13
  401c08:	pop    r14
  401c0a:	pop    r15
  401c0c:	pop    rbp
  401c0d:	ret    
  401c0e:	mov    DWORD PTR [rsp-0xc],0x0
  401c16:	xor    edx,edx
  401c18:	jmp    4018bb <leaf_tile+0x20b>
  401c1d:	xor    ecx,ecx
  401c1f:	xor    edx,edx
  401c21:	jmp    401b48 <leaf_tile+0x498>
  401c26:	xor    esi,esi
  401c28:	jmp    401aac <leaf_tile+0x3fc>

Disassembly of section .fini:
