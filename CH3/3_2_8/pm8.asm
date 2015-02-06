;[map symbols pmtest.map]
;============================================
; pm8.asm
; Date: 2015/01/29
; disable map file generation.
; log:
; copy from pm7_setup.asm(remove test memory read/write)
;============================================
%include 	"pm.inc"	;定义一些常量,宏及说明

org 0100h
jmp	LABLE_BEGIN

PageDirBase	equ	200000h	; page directory start address: 2M
PageTblBase	equ	201000h; page table start address: 2M+4K
LinearAddrDemo	equ	00401000h
ProcFoo		equ	00401000h
ProcBar		equ	00501000h
ProcPagingDemo	equ	00301000h
[SECTION .gdt]
;GDT

;				Base Addr	Limit		Attitue
LABEL_GDT:	Descriptor	0,		0,		0	;dummy
LABEL_DESC_NORMAL:	Descriptor	       0,            0ffffh, DA_DRW		; Normal 描述符
LABEL_DESC_CODE32: Descriptor	0,	SegCode32Len-1,		DA_C + DA_32 ;非 一致码段
LABEL_DESC_DATA: Descriptor	0,	DataLen-1,		DA_DRW ; Data
LABEL_DESC_STACK: Descriptor	0,	TopOfStack,		DA_DRW+DA_32 ; Stack 32bit
LABEL_DESC_VIDEO:  Descriptor	0B8000h,	0ffffh,		DA_DRW	;显存
LABEL_DESC_PAGE_DIR: Descriptor	PageDirBase,	4095,		DA_DRW	; page directory
LABEL_DESC_PAGE_TBL: Descriptor	PageTblBase,	1023,		DA_DRW | DA_LIMIT_4K; page tables
LABEL_DESC_FLAT_C: Descriptor	0,	0fffffh,		DA_CR|DA_32|DA_LIMIT_4K ; 0-4G
LABEL_DESC_FLAT_RW: Descriptor	0,	0fffffh,		DA_DRW|DA_LIMIT_4K ; 0-4G
;GDT End

GDTLen		equ	$-LABEL_GDT
GdtPtr		dw	GDTLen-1	;GDT Limit
		dd	0		;GDT BASE ADDR

;GDT Selector
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32	equ	LABEL_DESC_CODE32-LABEL_GDT
SelectorData	equ	LABEL_DESC_DATA-LABEL_GDT
SelectorStack	equ	LABEL_DESC_STACK-LABEL_GDT
SelectorVideo	equ	LABEL_DESC_VIDEO-LABEL_GDT
SelectorPageDir	equ	LABEL_DESC_PAGE_DIR - LABEL_GDT
SelectorPageTbl	equ	LABEL_DESC_PAGE_TBL - LABEL_GDT
SelectorFlatC	equ	LABEL_DESC_FLAT_C- LABEL_GDT
SelectorFlatRW	equ	LABEL_DESC_FLAT_RW- LABEL_GDT
;End of [section .gdt]

[SECTION .data1]
ALIGN 32
[BITS 32]
LABEL_DATA:
PMMessage:	db	"In Protect Mode Now. ^_^",0Ah, 0Ah,  0	; display in protect mode
_szMemChkTitle:			db	"BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0	; 
_szRAMSize			db	"RAM size:", 0
_szReturn			db	0Ah, 0
; 变量
_wSPValueInRealMode		dw	0
_dwMCRNumber:			dd	0	; Memory Check Result
_dwDispPos:			dd	(80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列。
_dwMemSize:			dd	0
_PageTableNumber		dw	0
_ARDStruct:			; Address Range Descriptor Structure
	_dwBaseAddrLow:		dd	0
	_dwBaseAddrHigh:	dd	0
	_dwLengthLow:		dd	0
	_dwLengthHigh:		dd	0
	_dwType:		dd	0
_MemChkBuf:	times	256	db	0

; 保护模式下使用这些符号
OffsetPMMessage	equ	PMMessage-$$
szMemChkTitle		equ	_szMemChkTitle	- $$
szRAMSize		equ	_szRAMSize	- $$
szReturn		equ	_szReturn	- $$
dwDispPos		equ	_dwDispPos	- $$
dwMemSize		equ	_dwMemSize	- $$
dwMCRNumber		equ	_dwMCRNumber	- $$
PageTableNumber		equ	_PageTableNumber	- $$
ARDStruct		equ	_ARDStruct	- $$
	dwBaseAddrLow	equ	_dwBaseAddrLow	- $$
	dwBaseAddrHigh	equ	_dwBaseAddrHigh	- $$
	dwLengthLow	equ	_dwLengthLow	- $$
	dwLengthHigh	equ	_dwLengthHigh	- $$
	dwType		equ	_dwType		- $$
MemChkBuf	equ	_MemChkBuf-$$
DataLen		equ	$-LABEL_DATA
; END of [SECTION .data1]

[SECTION .gs]
ALIGN 32
[BITS 32]
LABEL_STACK:
	times	512 	db	0
TopOfStack	equ	$-LABEL_STACK-1
; END of [SECTION .gs]

[SECTION .s16]
[BITS 16]
LABLE_BEGIN:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h
	

 ;Get memory information
	mov	ebx, 0
	mov	di, _MemChkBuf
.loop:
	mov	eax, 0E820h
	mov	ecx, 20
	mov	edx, 0534D4150h
	int	15h
	jc	LABEL_MEM_CHK_FAIL
	add	di, 20
	inc	dword [_dwMCRNumber]
	cmp	ebx, 0
	jne	.loop
	jmp	LABEL_MEM_CHK_OK
LABEL_MEM_CHK_FAIL:
	mov	dword [_dwMCRNumber], 0
LABEL_MEM_CHK_OK:
;初始化32位代码段descriptor
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32+2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32+4], al
	mov	byte [LABEL_DESC_CODE32+7], ah

;初始化data segment descriptor
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA+2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA+4], al
	mov	byte [LABEL_DESC_DATA+7], ah

;初始化stack segment descriptor
	xor	eax, eax
	mov	ax, ss
	shl	eax, 4
	add	eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK+2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK+4], al
	mov	byte [LABEL_DESC_STACK+7], ah

;prepare for loading GDTR
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT
	mov	dword [GdtPtr+2], eax

;load GDTR
	lgdt	[GdtPtr]

;disable interrupt
	cli

;A20 address line open
	in 	al, 92h
	or	al, 00000010b
	out	92h, al

;prepare to switch to protect mode.
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

;enter protect mode
	jmp	dword SelectorCode32:0

;End of [SECTION .s16]

[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:	
	mov	ax, SelectorData
	mov	ds, ax		;data seg selector
	mov	ax, SelectorData
	mov	es, ax		;data seg selector
	mov	ax, SelectorVideo
	mov	gs, ax		;video seg selector
	mov	ax, SelectorStack
	mov	ss, ax		;stack seg selector

	mov	esp, TopOfStack

	; 下面显示一个字符串
	push	OffsetPMMessage
	call	DispStr
	add	esp, 4

	push	szMemChkTitle
	call	DispStr
	add	esp, 4

	call	DispMemSize
	call 	SetupPaging
	jmp	$
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DispMemSize:
	push	esi
	push 	edi
	push	ecx

	mov	esi, MemChkBuf
	mov	ecx, [dwMCRNumber]
.loop:
	mov	edx, 5
	mov	edi, ARDStruct
.1:
	push	dword [esi]
	call	DispInt
	pop 	eax
	stosd
	add	esi, 4
	dec	edx
	cmp	edx, 0
	jnz	.1
	call	DispReturn
	cmp	dword [dwType], 1	;xxx
	jne	.2
	mov	eax, [dwBaseAddrLow]	;xxx
	add	eax, [dwLengthLow]	;xxx
	cmp	eax, [dwMemSize]	;xxx
	jb	.2
	mov	[dwMemSize], eax
.2:
	loop	.loop

	call	DispReturn
	push	szRAMSize		;xxx
	call	DispStr			
	add	esp, 4

	push	dword [dwMemSize]
	call	DispInt
	add	esp, 4

	pop	ecx
	pop	edi
	pop	esi
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetupPaging:
	; init page directory
	xor	edx, edx
	mov	eax, [dwMemSize]	; the segment first address is PageDirBase
	mov	ebx, 400000h
	div	ebx
	mov	ecx, eax
	test	edx, edx
	jz	.no_remainer
	inc	ecx
.no_remainer:
	mov	[PageTableNumber], ecx
	mov	ax, SelectorFlatRW
	mov	es, ax
	mov	edi, PageDirBase0
	xor	eax, eax
	mov	eax, PageTblBase0 | PG_P | PG_USU | PG_RWW
.1:
	stosd		; mov es:edi, ax  inc di
	add	eax, 4096
	loop	.1

	; init all page table
	mov	eax, [PageTableNumber]
	mov	ebx, 1024
	mul	ebx
	mov	ecx, eax
	mov	edi, PageTblBase0 
	xor	eax, eax
	mov	eax, PG_P | PG_USU |PG_RWW
.2:
	stosd
	add	eax, 4096
	loop	.2

	mov	eax, PageDirBase0
	mov	cr3, eax
	mov	eax, cr0
	or	eax, 80000000h
	mov	cr0, eax
	jmp	short .3
.3:
	nop

	ret

PagingDemo:
	mov	ax, cs
	mov	ds, ax
	mov	ax, SelectorFlatRW
	mov	es, ax

	push	LenFoo
	push 	OffsetFoo
	push	ProcFoo
	call 	MemCpy
	add	esp, 12

	push	LenBar
	push 	OffsetBar
	push	ProcBar
	call 	MemCpy
	add	esp, 12

	push	LenPagingDemoAll
	push 	OffsetPagingDemoProc
	push	ProcPagingDemo
	call 	MemCpy
	add	esp, 12

	mov	ax, SelectorData
	mov	ds, ax
	mov	es, ax

	call	SetupPaging

	call 	SelectorFlatC:ProcPagingDemo
	call	PSwitch
	call 	SelectorFlatC:ProcPagingDemo
	ret
%include 	"lib.inc"	
SegCode32Len	equ	$-LABEL_SEG_CODE32
;END of [SECTION .s32]
