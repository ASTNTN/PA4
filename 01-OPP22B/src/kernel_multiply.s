	.file	"PolyMult.c"
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	kernel_multiply
	.type	kernel_multiply, @function
kernel_multiply:
.LFB12:
	.cfi_startproc
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	mov	eax, esi
	mov	rbp, rsp
	.cfi_def_cfa_register 6
	push	r15
	push	r14
	.cfi_offset 15, -24
	.cfi_offset 14, -32
	mov	r14d, esi
	push	r13
	.cfi_offset 13, -40
	mov	r13d, ecx
	push	r12
	.cfi_offset 12, -48
	mov	r12, rdi
	push	rbx
	.cfi_offset 3, -56
	mov	rbx, rdx
	and	rsp, -32
	sub	rsp, 32
	add	eax, ecx
	js	.L2
	cdqe
	mov	rdi, r8
	xor	esi, esi
	lea	rdx, [4+rax*4]
	call	memset
	mov	r8, rax
.L2:
	mov	eax, r14d
	or	eax, r13d
	js	.L15
	lea	r15d, [r13+1]
	mov	edi, r14d
	mov	rax, r8
	xor	esi, esi
	mov	edx, r15d
	mov	QWORD PTR [rsp+24], rdi
	mov	r14d, r15d
	shr	edx, 3
	and	r14d, -8
	lea	edi, [rdx-1]
	add	rdi, 1
	sal	rdi, 5
	.p2align 4,,10
	.p2align 3
.L4:
	vmovss	xmm1, DWORD PTR [r12+rsi*4]
	mov	r11d, esi
	xor	edx, edx
	vbroadcastss	ymm2, xmm1
	cmp	r13d, 6
	jbe	.L18
	.p2align 4,,10
	.p2align 3
.L5:
	vmovups	ymm0, YMMWORD PTR [rbx+rdx]
	vfmadd213ps	ymm0, ymm2, YMMWORD PTR [rax+rdx]
	.byte	0x0f, 0x1f, 0x44, 0x00, 0x00	# 5-byte NOP: nop DWORD PTR [rax+rax*1+0x0], same length as the removed store
	add	rdx, 32
	cmp	rdx, rdi
	jne	.L5
	cmp	r15d, r14d
	je	.L6
	mov	ecx, r14d
	mov	edx, r14d
.L9:
	mov	r9d, r13d
	sub	r9d, ecx
	lea	r10d, [r9+1]
	cmp	r9d, 2
	jbe	.L7
	lea	r9, [rsi+rcx]
	vshufps	xmm0, xmm1, xmm1, 0
	lea	r9, [r8+r9*4]
	vmovups	xmm3, XMMWORD PTR [r9]
	vfmadd132ps	xmm0, xmm3, XMMWORD PTR [rbx+rcx*4]
	mov	ecx, r10d
	and	ecx, -4
	add	edx, ecx
	vmovups	XMMWORD PTR [r9], xmm0
	cmp	r10d, ecx
	je	.L6
.L7:
	lea	ecx, [r11+rdx]
	movsx	r9, edx
	movsx	rcx, ecx
	vmovss	xmm0, DWORD PTR [rbx+r9*4]
	lea	r10, [0+r9*4]
	lea	rcx, [r8+rcx*4]
	vfmadd213ss	xmm0, xmm1, DWORD PTR [rcx]
	vmovss	DWORD PTR [rcx], xmm0
	lea	ecx, [rdx+1]
	cmp	r13d, ecx
	jl	.L6
	add	ecx, r11d
	vmovss	xmm0, DWORD PTR [rbx+4+r10]
	add	edx, 2
	movsx	rcx, ecx
	lea	rcx, [r8+rcx*4]
	vfmadd213ss	xmm0, xmm1, DWORD PTR [rcx]
	vmovss	DWORD PTR [rcx], xmm0
	cmp	r13d, edx
	jl	.L6
	add	edx, r11d
	movsx	rdx, edx
	lea	rdx, [r8+rdx*4]
	vmovss	xmm4, DWORD PTR [rdx]
	vfmadd132ss	xmm1, xmm4, DWORD PTR [rbx+8+r10]
	vmovss	DWORD PTR [rdx], xmm1
.L6:
	lea	rdx, [rsi+1]
	add	rax, 4
	cmp	rsi, QWORD PTR [rsp+24]
	je	.L14
	mov	rsi, rdx
	jmp	.L4
	.p2align 4,,10
	.p2align 3
.L14:
	vzeroupper
.L15:
	lea	rsp, [rbp-40]
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	.cfi_remember_state
	.cfi_def_cfa 7, 8
	ret
.L18:
	.cfi_restore_state
	xor	ecx, ecx
	xor	edx, edx
	jmp	.L9
	.cfi_endproc
.LFE12:
	.size	kernel_multiply, .-kernel_multiply
	.ident	"GCC: (GNU) 11.5.0 20240719 (Red Hat 11.5.0-14)"
	.section	.note.GNU-stack,"",@progbits
