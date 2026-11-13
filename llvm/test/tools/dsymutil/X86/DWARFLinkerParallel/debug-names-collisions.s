# Check the .debug_names table of the parallel linker: names whose hashes
# collide are ordered by name within their bucket, the entries of a name are
# ordered by DIE offset, and DW_IDX_parent refers to the entry of an indexed
# parent and is a flag for a parent which is not indexed.

# RUN: llvm-mc -triple x86_64-apple-darwin -filetype=obj %s -o %t.o
# RUN: echo '---' > %t.map
# RUN: echo "triple:          'x86_64-apple-darwin'" >> %t.map
# RUN: echo 'objects:'  >> %t.map
# RUN: echo " -  filename: '%t.o'" >> %t.map
# RUN: echo '    symbols:' >> %t.map
# RUN: echo '      - { sym: __Z2ezi, objAddr: 0x0, binAddr: 0x10000, size: 0x20 }' >> %t.map
# RUN: echo '      - { sym: __ZN1N2FYENS_5OuterE, objAddr: 0x20, binAddr: 0x10020, size: 0x10 }' >> %t.map
# RUN: echo '      - { sym: __ZN1N2EzENS_5OuterE, objAddr: 0x30, binAddr: 0x10030, size: 0x10 }' >> %t.map
# RUN: echo '      - { sym: __Z2Ezi, objAddr: 0x40, binAddr: 0x10040, size: 0x10 }' >> %t.map
# RUN: echo '      - { sym: _main, objAddr: 0x50, binAddr: 0x10050, size: 0x70 }' >> %t.map
# RUN: echo '...' >> %t.map

# RUN: dsymutil --linker=parallel --accelerator=Dwarf -y %t.map -f -o %t.dSYM
# RUN: llvm-dwarfdump --verify %t.dSYM | FileCheck %s --check-prefix=VERIFY
# RUN: llvm-dwarfdump --debug-names %t.dSYM | FileCheck %s

## The output does not depend on the number of threads.
# RUN: dsymutil --linker=parallel --accelerator=Dwarf -y %t.map -f -o %t.2.dSYM --num-threads 2
# RUN: llvm-dwarfdump --debug-names %t.dSYM | sed 1d > %t.txt
# RUN: llvm-dwarfdump --debug-names %t.2.dSYM | sed 1d > %t.2.txt
# RUN: diff %t.txt %t.2.txt

# VERIFY: No errors.

## The "Inner" of ez() is recorded before N::Outer::Inner, but comes after it
## in the type unit.
# CHECK:        String: {{.*}} "Inner"
# CHECK-NEXT:   Entry @ {{.*}} {
# CHECK-NEXT:     Abbrev: {{.*}}
# CHECK-NEXT:     Tag: DW_TAG_structure_type
# CHECK-NEXT:     DW_IDX_compile_unit: 0x00
# CHECK-NEXT:     DW_IDX_die_offset: 0x00000040
# CHECK-NEXT:   }
# CHECK-NEXT:   Entry @ {{.*}} {
# CHECK-NEXT:     Abbrev: {{.*}}
# CHECK-NEXT:     Tag: DW_TAG_structure_type
# CHECK-NEXT:     DW_IDX_compile_unit: 0x00
# CHECK-NEXT:     DW_IDX_die_offset: 0x00000072
# CHECK-NEXT:   }
# CHECK-NEXT: }

# CHECK:        Hash: 0x2B613
# CHECK-NEXT:   String: {{.*}} "N"
# CHECK-NEXT:   Entry @ {{.*}} {
# CHECK-NEXT:     Abbrev: {{.*}}
# CHECK-NEXT:     Tag: DW_TAG_namespace
# CHECK-NEXT:     DW_IDX_compile_unit: 0x00
# CHECK-NEXT:     DW_IDX_die_offset: {{.*}}
# CHECK-NEXT:   }
# CHECK-NEXT:   Entry @ [[N:0x[0-9a-f]+]] {
# CHECK-NEXT:     Abbrev: {{.*}}
# CHECK-NEXT:     Tag: DW_TAG_namespace
# CHECK-NEXT:     DW_IDX_compile_unit: 0x01
# CHECK-NEXT:     DW_IDX_die_offset: {{.*}}
# CHECK-NEXT:     DW_IDX_parent: <parent not indexed>

## "Ez" and "ez" have the same case-folded hash, and so do their mangled names.
## ez() is defined first, but the names are ordered by name within their bucket.
# CHECK:        Hash: 0x5977C4
# CHECK-NEXT:   String: {{.*}} "Ez"
# CHECK-NEXT:   Entry @ {{.*}} {
# CHECK-NEXT:     Abbrev: {{.*}}
# CHECK-NEXT:     Tag: DW_TAG_subprogram
# CHECK-NEXT:     DW_IDX_compile_unit: 0x01
# CHECK-NEXT:     DW_IDX_die_offset: {{.*}}
# CHECK-NEXT:     DW_IDX_parent: Entry @ [[N]]
# CHECK-NEXT:   }
# CHECK-NEXT:   Entry @ {{.*}} {
# CHECK-NEXT:     Abbrev: {{.*}}
# CHECK-NEXT:     Tag: DW_TAG_subprogram
# CHECK-NEXT:     DW_IDX_compile_unit: 0x01
# CHECK-NEXT:     DW_IDX_die_offset: {{.*}}
# CHECK-NEXT:     DW_IDX_parent: <parent not indexed>
# CHECK-NEXT:   }
# CHECK-NEXT: }
# CHECK-NEXT: Name {{[0-9]+}} {
# CHECK-NEXT:   Hash: 0x5977C4
# CHECK-NEXT:   String: {{.*}} "ez"
# CHECK:        Hash: 0xEE35EEB8
# CHECK-NEXT:   String: {{.*}} "_Z2Ezi"
# CHECK:        Hash: 0xEE35EEB8
# CHECK-NEXT:   String: {{.*}} "_Z2ezi"

## Generated from:
## namespace N {
## struct Outer {
##   struct Inner {
##     int x;
##   } i;
## };
## } // namespace N
##
## int ez(int x) {
##   struct Inner {
##     int a;
##   } l = {x};
##   return -l.a;
## }
##
## namespace N {
## int FY(Outer o) { return o.i.x + 1; }
## int Ez(Outer o) { return o.i.x; }
## } // namespace N
##
## int Ez(int x) { return x; }
##
## int main() { return N::Ez({}) + N::FY({}) + Ez(1) + ez(1); }
## with: clang++ -target x86_64-apple-macos12 -O0 -g -gdwarf-5 -S

	.section	__TEXT,__text,regular,pure_instructions
	.globl	__Z2ezi                         ## -- Begin function _Z2ezi
	.p2align	4
__Z2ezi:                                ## @_Z2ezi
Lfunc_begin0:
	.file	0 "/tmp" "accel.cpp" md5 0xcdfcd56057ba6f547aabf329c488d348
	.loc	0 9 0                           ## accel.cpp:9:0
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	movl	%edi, -4(%rbp)
Ltmp0:
	.loc	0 12 10 prologue_end            ## accel.cpp:12:10
	movl	-4(%rbp), %eax
	.loc	0 12 9 is_stmt 0                ## accel.cpp:12:9
	movl	%eax, -8(%rbp)
	.loc	0 13 10 is_stmt 1               ## accel.cpp:13:10
	xorl	%eax, %eax
	subl	-8(%rbp), %eax
	.loc	0 13 3 epilogue_begin is_stmt 0 ## accel.cpp:13:3
	popq	%rbp
	retq
Ltmp1:
Lfunc_end0:
	.cfi_endproc
                                        ## -- End function
	.globl	__ZN1N2FYENS_5OuterE            ## -- Begin function _ZN1N2FYENS_5OuterE
	.p2align	4
__ZN1N2FYENS_5OuterE:                   ## @_ZN1N2FYENS_5OuterE
Lfunc_begin1:
	.loc	0 17 0 is_stmt 1                ## accel.cpp:17:0
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	movl	%edi, -4(%rbp)
Ltmp2:
	.loc	0 17 30 prologue_end            ## accel.cpp:17:30
	movl	-4(%rbp), %eax
	.loc	0 17 32 is_stmt 0               ## accel.cpp:17:32
	addl	$1, %eax
	.loc	0 17 19 epilogue_begin          ## accel.cpp:17:19
	popq	%rbp
	retq
Ltmp3:
Lfunc_end1:
	.cfi_endproc
                                        ## -- End function
	.globl	__ZN1N2EzENS_5OuterE            ## -- Begin function _ZN1N2EzENS_5OuterE
	.p2align	4
__ZN1N2EzENS_5OuterE:                   ## @_ZN1N2EzENS_5OuterE
Lfunc_begin2:
	.loc	0 18 0 is_stmt 1                ## accel.cpp:18:0
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	movl	%edi, -4(%rbp)
Ltmp4:
	.loc	0 18 30 prologue_end            ## accel.cpp:18:30
	movl	-4(%rbp), %eax
	.loc	0 18 19 epilogue_begin is_stmt 0 ## accel.cpp:18:19
	popq	%rbp
	retq
Ltmp5:
Lfunc_end2:
	.cfi_endproc
                                        ## -- End function
	.globl	__Z2Ezi                         ## -- Begin function _Z2Ezi
	.p2align	4
__Z2Ezi:                                ## @_Z2Ezi
Lfunc_begin3:
	.loc	0 21 0 is_stmt 1                ## accel.cpp:21:0
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	movl	%edi, -4(%rbp)
Ltmp6:
	.loc	0 21 24 prologue_end            ## accel.cpp:21:24
	movl	-4(%rbp), %eax
	.loc	0 21 17 epilogue_begin is_stmt 0 ## accel.cpp:21:17
	popq	%rbp
	retq
Ltmp7:
Lfunc_end3:
	.cfi_endproc
                                        ## -- End function
	.globl	_main                           ## -- Begin function main
	.p2align	4
_main:                                  ## @main
Lfunc_begin4:
	.loc	0 23 0 is_stmt 1                ## accel.cpp:23:0
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	subq	$32, %rsp
	movl	$0, -4(%rbp)
Ltmp8:
	.loc	0 23 28 prologue_end            ## accel.cpp:23:28
	movl	$0, -8(%rbp)
	.loc	0 23 21 is_stmt 0               ## accel.cpp:23:21
	movl	-8(%rbp), %edi
	callq	__ZN1N2EzENS_5OuterE
	movl	%eax, -24(%rbp)                 ## 4-byte Spill
	.loc	0 23 40                         ## accel.cpp:23:40
	movl	$0, -12(%rbp)
	.loc	0 23 33                         ## accel.cpp:23:33
	movl	-12(%rbp), %edi
	callq	__ZN1N2FYENS_5OuterE
	movl	%eax, %ecx
	movl	-24(%rbp), %eax                 ## 4-byte Reload
	.loc	0 23 31                         ## accel.cpp:23:31
	addl	%ecx, %eax
	movl	%eax, -20(%rbp)                 ## 4-byte Spill
	.loc	0 23 45                         ## accel.cpp:23:45
	movl	$1, %edi
	callq	__Z2Ezi
	movl	%eax, %ecx
	movl	-20(%rbp), %eax                 ## 4-byte Reload
	.loc	0 23 43                         ## accel.cpp:23:43
	addl	%ecx, %eax
	movl	%eax, -16(%rbp)                 ## 4-byte Spill
	.loc	0 23 53                         ## accel.cpp:23:53
	movl	$1, %edi
	callq	__Z2ezi
	movl	%eax, %ecx
	movl	-16(%rbp), %eax                 ## 4-byte Reload
	.loc	0 23 51                         ## accel.cpp:23:51
	addl	%ecx, %eax
	.loc	0 23 14 epilogue_begin          ## accel.cpp:23:14
	addq	$32, %rsp
	popq	%rbp
	retq
Ltmp9:
Lfunc_end4:
	.cfi_endproc
                                        ## -- End function
	.section	__DWARF,__debug_abbrev,regular,debug
Lsection_abbrev:
	.byte	1                               ## Abbreviation Code
	.byte	17                              ## DW_TAG_compile_unit
	.byte	1                               ## DW_CHILDREN_yes
	.byte	37                              ## DW_AT_producer
	.byte	37                              ## DW_FORM_strx1
	.byte	19                              ## DW_AT_language
	.byte	5                               ## DW_FORM_data2
	.byte	3                               ## DW_AT_name
	.byte	37                              ## DW_FORM_strx1
	.ascii	"\202|"                         ## DW_AT_LLVM_sysroot
	.byte	37                              ## DW_FORM_strx1
	.byte	114                             ## DW_AT_str_offsets_base
	.byte	23                              ## DW_FORM_sec_offset
	.byte	16                              ## DW_AT_stmt_list
	.byte	23                              ## DW_FORM_sec_offset
	.byte	27                              ## DW_AT_comp_dir
	.byte	37                              ## DW_FORM_strx1
	.byte	17                              ## DW_AT_low_pc
	.byte	27                              ## DW_FORM_addrx
	.byte	18                              ## DW_AT_high_pc
	.byte	6                               ## DW_FORM_data4
	.byte	115                             ## DW_AT_addr_base
	.byte	23                              ## DW_FORM_sec_offset
	.byte	0                               ## EOM(1)
	.byte	0                               ## EOM(2)
	.byte	2                               ## Abbreviation Code
	.byte	46                              ## DW_TAG_subprogram
	.byte	1                               ## DW_CHILDREN_yes
	.byte	17                              ## DW_AT_low_pc
	.byte	27                              ## DW_FORM_addrx
	.byte	18                              ## DW_AT_high_pc
	.byte	6                               ## DW_FORM_data4
	.byte	64                              ## DW_AT_frame_base
	.byte	24                              ## DW_FORM_exprloc
	.byte	110                             ## DW_AT_linkage_name
	.byte	37                              ## DW_FORM_strx1
	.byte	3                               ## DW_AT_name
	.byte	37                              ## DW_FORM_strx1
	.byte	58                              ## DW_AT_decl_file
	.byte	11                              ## DW_FORM_data1
	.byte	59                              ## DW_AT_decl_line
	.byte	11                              ## DW_FORM_data1
	.byte	73                              ## DW_AT_type
	.byte	19                              ## DW_FORM_ref4
	.byte	63                              ## DW_AT_external
	.byte	25                              ## DW_FORM_flag_present
	.byte	0                               ## EOM(1)
	.byte	0                               ## EOM(2)
	.byte	3                               ## Abbreviation Code
	.byte	5                               ## DW_TAG_formal_parameter
	.byte	0                               ## DW_CHILDREN_no
	.byte	2                               ## DW_AT_location
	.byte	24                              ## DW_FORM_exprloc
	.byte	3                               ## DW_AT_name
	.byte	37                              ## DW_FORM_strx1
	.byte	58                              ## DW_AT_decl_file
	.byte	11                              ## DW_FORM_data1
	.byte	59                              ## DW_AT_decl_line
	.byte	11                              ## DW_FORM_data1
	.byte	73                              ## DW_AT_type
	.byte	19                              ## DW_FORM_ref4
	.byte	0                               ## EOM(1)
	.byte	0                               ## EOM(2)
	.byte	4                               ## Abbreviation Code
	.byte	52                              ## DW_TAG_variable
	.byte	0                               ## DW_CHILDREN_no
	.byte	2                               ## DW_AT_location
	.byte	24                              ## DW_FORM_exprloc
	.byte	3                               ## DW_AT_name
	.byte	37                              ## DW_FORM_strx1
	.byte	58                              ## DW_AT_decl_file
	.byte	11                              ## DW_FORM_data1
	.byte	59                              ## DW_AT_decl_line
	.byte	11                              ## DW_FORM_data1
	.byte	73                              ## DW_AT_type
	.byte	19                              ## DW_FORM_ref4
	.byte	0                               ## EOM(1)
	.byte	0                               ## EOM(2)
	.byte	5                               ## Abbreviation Code
	.byte	19                              ## DW_TAG_structure_type
	.byte	1                               ## DW_CHILDREN_yes
	.byte	54                              ## DW_AT_calling_convention
	.byte	11                              ## DW_FORM_data1
	.byte	3                               ## DW_AT_name
	.byte	37                              ## DW_FORM_strx1
	.byte	11                              ## DW_AT_byte_size
	.byte	11                              ## DW_FORM_data1
	.byte	58                              ## DW_AT_decl_file
	.byte	11                              ## DW_FORM_data1
	.byte	59                              ## DW_AT_decl_line
	.byte	11                              ## DW_FORM_data1
	.byte	0                               ## EOM(1)
	.byte	0                               ## EOM(2)
	.byte	6                               ## Abbreviation Code
	.byte	13                              ## DW_TAG_member
	.byte	0                               ## DW_CHILDREN_no
	.byte	3                               ## DW_AT_name
	.byte	37                              ## DW_FORM_strx1
	.byte	73                              ## DW_AT_type
	.byte	19                              ## DW_FORM_ref4
	.byte	58                              ## DW_AT_decl_file
	.byte	11                              ## DW_FORM_data1
	.byte	59                              ## DW_AT_decl_line
	.byte	11                              ## DW_FORM_data1
	.byte	56                              ## DW_AT_data_member_location
	.byte	11                              ## DW_FORM_data1
	.byte	0                               ## EOM(1)
	.byte	0                               ## EOM(2)
	.byte	7                               ## Abbreviation Code
	.byte	57                              ## DW_TAG_namespace
	.byte	1                               ## DW_CHILDREN_yes
	.byte	3                               ## DW_AT_name
	.byte	37                              ## DW_FORM_strx1
	.byte	0                               ## EOM(1)
	.byte	0                               ## EOM(2)
	.byte	8                               ## Abbreviation Code
	.byte	46                              ## DW_TAG_subprogram
	.byte	0                               ## DW_CHILDREN_no
	.byte	17                              ## DW_AT_low_pc
	.byte	27                              ## DW_FORM_addrx
	.byte	18                              ## DW_AT_high_pc
	.byte	6                               ## DW_FORM_data4
	.byte	64                              ## DW_AT_frame_base
	.byte	24                              ## DW_FORM_exprloc
	.byte	3                               ## DW_AT_name
	.byte	37                              ## DW_FORM_strx1
	.byte	58                              ## DW_AT_decl_file
	.byte	11                              ## DW_FORM_data1
	.byte	59                              ## DW_AT_decl_line
	.byte	11                              ## DW_FORM_data1
	.byte	73                              ## DW_AT_type
	.byte	19                              ## DW_FORM_ref4
	.byte	63                              ## DW_AT_external
	.byte	25                              ## DW_FORM_flag_present
	.byte	0                               ## EOM(1)
	.byte	0                               ## EOM(2)
	.byte	9                               ## Abbreviation Code
	.byte	36                              ## DW_TAG_base_type
	.byte	0                               ## DW_CHILDREN_no
	.byte	3                               ## DW_AT_name
	.byte	37                              ## DW_FORM_strx1
	.byte	62                              ## DW_AT_encoding
	.byte	11                              ## DW_FORM_data1
	.byte	11                              ## DW_AT_byte_size
	.byte	11                              ## DW_FORM_data1
	.byte	0                               ## EOM(1)
	.byte	0                               ## EOM(2)
	.byte	0                               ## EOM(3)
	.section	__DWARF,__debug_info,regular,debug
Lsection_info:
Lcu_begin0:
Lset0 = Ldebug_info_end0-Ldebug_info_start0 ## Length of Unit
	.long	Lset0
Ldebug_info_start0:
	.short	5                               ## DWARF version number
	.byte	1                               ## DWARF Unit Type
	.byte	8                               ## Address Size (in bytes)
Lset1 = Lsection_abbrev-Lsection_abbrev ## Offset Into Abbrev. Section
	.long	Lset1
	.byte	1                               ## Abbrev [1] 0xc:0xda DW_TAG_compile_unit
	.byte	0                               ## DW_AT_producer
	.short	33                              ## DW_AT_language
	.byte	1                               ## DW_AT_name
	.byte	2                               ## DW_AT_LLVM_sysroot
Lset2 = Lstr_offsets_base0-Lsection_str_off ## DW_AT_str_offsets_base
	.long	Lset2
Lset3 = Lline_table_start0-Lsection_line ## DW_AT_stmt_list
	.long	Lset3
	.byte	3                               ## DW_AT_comp_dir
	.byte	0                               ## DW_AT_low_pc
Lset4 = Lfunc_end4-Lfunc_begin0         ## DW_AT_high_pc
	.long	Lset4
Lset5 = Laddr_table_base0-Lsection_info0 ## DW_AT_addr_base
	.long	Lset5
	.byte	2                               ## Abbrev [2] 0x24:0x37 DW_TAG_subprogram
	.byte	0                               ## DW_AT_low_pc
Lset6 = Lfunc_end0-Lfunc_begin0         ## DW_AT_high_pc
	.long	Lset6
	.byte	1                               ## DW_AT_frame_base
	.byte	86
	.byte	8                               ## DW_AT_linkage_name
	.byte	9                               ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	9                               ## DW_AT_decl_line
	.long	225                             ## DW_AT_type
                                        ## DW_AT_external
	.byte	3                               ## Abbrev [3] 0x34:0xb DW_TAG_formal_parameter
	.byte	2                               ## DW_AT_location
	.byte	145
	.byte	124
	.byte	16                              ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	9                               ## DW_AT_decl_line
	.long	225                             ## DW_AT_type
	.byte	4                               ## Abbrev [4] 0x3f:0xb DW_TAG_variable
	.byte	2                               ## DW_AT_location
	.byte	145
	.byte	120
	.byte	17                              ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	12                              ## DW_AT_decl_line
	.long	74                              ## DW_AT_type
	.byte	5                               ## Abbrev [5] 0x4a:0x10 DW_TAG_structure_type
	.byte	5                               ## DW_AT_calling_convention
	.byte	7                               ## DW_AT_name
	.byte	4                               ## DW_AT_byte_size
	.byte	0                               ## DW_AT_decl_file
	.byte	10                              ## DW_AT_decl_line
	.byte	6                               ## Abbrev [6] 0x50:0x9 DW_TAG_member
	.byte	5                               ## DW_AT_name
	.long	225                             ## DW_AT_type
	.byte	0                               ## DW_AT_decl_file
	.byte	11                              ## DW_AT_decl_line
	.byte	0                               ## DW_AT_data_member_location
	.byte	0                               ## End Of Children Mark
	.byte	0                               ## End Of Children Mark
	.byte	7                               ## Abbrev [7] 0x5b:0x5b DW_TAG_namespace
	.byte	4                               ## DW_AT_name
	.byte	2                               ## Abbrev [2] 0x5d:0x1c DW_TAG_subprogram
	.byte	1                               ## DW_AT_low_pc
Lset7 = Lfunc_end1-Lfunc_begin1         ## DW_AT_high_pc
	.long	Lset7
	.byte	1                               ## DW_AT_frame_base
	.byte	86
	.byte	10                              ## DW_AT_linkage_name
	.byte	11                              ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	17                              ## DW_AT_decl_line
	.long	225                             ## DW_AT_type
                                        ## DW_AT_external
	.byte	3                               ## Abbrev [3] 0x6d:0xb DW_TAG_formal_parameter
	.byte	2                               ## DW_AT_location
	.byte	145
	.byte	124
	.byte	18                              ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	17                              ## DW_AT_decl_line
	.long	149                             ## DW_AT_type
	.byte	0                               ## End Of Children Mark
	.byte	2                               ## Abbrev [2] 0x79:0x1c DW_TAG_subprogram
	.byte	2                               ## DW_AT_low_pc
Lset8 = Lfunc_end2-Lfunc_begin2         ## DW_AT_high_pc
	.long	Lset8
	.byte	1                               ## DW_AT_frame_base
	.byte	86
	.byte	12                              ## DW_AT_linkage_name
	.byte	13                              ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	18                              ## DW_AT_decl_line
	.long	225                             ## DW_AT_type
                                        ## DW_AT_external
	.byte	3                               ## Abbrev [3] 0x89:0xb DW_TAG_formal_parameter
	.byte	2                               ## DW_AT_location
	.byte	145
	.byte	124
	.byte	18                              ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	18                              ## DW_AT_decl_line
	.long	149                             ## DW_AT_type
	.byte	0                               ## End Of Children Mark
	.byte	5                               ## Abbrev [5] 0x95:0x20 DW_TAG_structure_type
	.byte	5                               ## DW_AT_calling_convention
	.byte	20                              ## DW_AT_name
	.byte	4                               ## DW_AT_byte_size
	.byte	0                               ## DW_AT_decl_file
	.byte	2                               ## DW_AT_decl_line
	.byte	6                               ## Abbrev [6] 0x9b:0x9 DW_TAG_member
	.byte	19                              ## DW_AT_name
	.long	164                             ## DW_AT_type
	.byte	0                               ## DW_AT_decl_file
	.byte	5                               ## DW_AT_decl_line
	.byte	0                               ## DW_AT_data_member_location
	.byte	5                               ## Abbrev [5] 0xa4:0x10 DW_TAG_structure_type
	.byte	5                               ## DW_AT_calling_convention
	.byte	7                               ## DW_AT_name
	.byte	4                               ## DW_AT_byte_size
	.byte	0                               ## DW_AT_decl_file
	.byte	3                               ## DW_AT_decl_line
	.byte	6                               ## Abbrev [6] 0xaa:0x9 DW_TAG_member
	.byte	16                              ## DW_AT_name
	.long	225                             ## DW_AT_type
	.byte	0                               ## DW_AT_decl_file
	.byte	4                               ## DW_AT_decl_line
	.byte	0                               ## DW_AT_data_member_location
	.byte	0                               ## End Of Children Mark
	.byte	0                               ## End Of Children Mark
	.byte	0                               ## End Of Children Mark
	.byte	2                               ## Abbrev [2] 0xb6:0x1c DW_TAG_subprogram
	.byte	3                               ## DW_AT_low_pc
Lset9 = Lfunc_end3-Lfunc_begin3         ## DW_AT_high_pc
	.long	Lset9
	.byte	1                               ## DW_AT_frame_base
	.byte	86
	.byte	14                              ## DW_AT_linkage_name
	.byte	13                              ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	21                              ## DW_AT_decl_line
	.long	225                             ## DW_AT_type
                                        ## DW_AT_external
	.byte	3                               ## Abbrev [3] 0xc6:0xb DW_TAG_formal_parameter
	.byte	2                               ## DW_AT_location
	.byte	145
	.byte	124
	.byte	16                              ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	21                              ## DW_AT_decl_line
	.long	225                             ## DW_AT_type
	.byte	0                               ## End Of Children Mark
	.byte	8                               ## Abbrev [8] 0xd2:0xf DW_TAG_subprogram
	.byte	4                               ## DW_AT_low_pc
Lset10 = Lfunc_end4-Lfunc_begin4        ## DW_AT_high_pc
	.long	Lset10
	.byte	1                               ## DW_AT_frame_base
	.byte	86
	.byte	15                              ## DW_AT_name
	.byte	0                               ## DW_AT_decl_file
	.byte	23                              ## DW_AT_decl_line
	.long	225                             ## DW_AT_type
                                        ## DW_AT_external
	.byte	9                               ## Abbrev [9] 0xe1:0x4 DW_TAG_base_type
	.byte	6                               ## DW_AT_name
	.byte	5                               ## DW_AT_encoding
	.byte	4                               ## DW_AT_byte_size
	.byte	0                               ## End Of Children Mark
Ldebug_info_end0:
	.section	__DWARF,__debug_str_offs,regular,debug
Lsection_str_off:
	.long	88                              ## Length of String Offsets Set
	.short	5
	.short	0
Lstr_offsets_base0:
	.section	__DWARF,__debug_str,regular,debug
Linfo_string:
	.asciz	"clang version 24.0.0git"       ## string offset=0 ; clang version 24.0.0git
	.asciz	"accel.cpp"                     ## string offset=24 ; accel.cpp
	.asciz	"/"                             ## string offset=34 ; /
	.asciz	"/tmp"                          ## string offset=36 ; /tmp
	.asciz	"ez"                            ## string offset=41 ; ez
	.asciz	"_Z2ezi"                        ## string offset=44 ; _Z2ezi
	.asciz	"N"                             ## string offset=51 ; N
	.asciz	"FY"                            ## string offset=53 ; FY
	.asciz	"_ZN1N2FYENS_5OuterE"           ## string offset=56 ; _ZN1N2FYENS_5OuterE
	.asciz	"Ez"                            ## string offset=76 ; Ez
	.asciz	"_ZN1N2EzENS_5OuterE"           ## string offset=79 ; _ZN1N2EzENS_5OuterE
	.asciz	"_Z2Ezi"                        ## string offset=99 ; _Z2Ezi
	.asciz	"main"                          ## string offset=106 ; main
	.asciz	"Inner"                         ## string offset=111 ; Inner
	.asciz	"a"                             ## string offset=117 ; a
	.asciz	"int"                           ## string offset=119 ; int
	.asciz	"x"                             ## string offset=123 ; x
	.asciz	"l"                             ## string offset=125 ; l
	.asciz	"o"                             ## string offset=127 ; o
	.asciz	"Outer"                         ## string offset=129 ; Outer
	.asciz	"i"                             ## string offset=135 ; i
	.section	__DWARF,__debug_str_offs,regular,debug
	.long	0
	.long	24
	.long	34
	.long	36
	.long	51
	.long	117
	.long	119
	.long	111
	.long	44
	.long	41
	.long	56
	.long	53
	.long	79
	.long	76
	.long	99
	.long	106
	.long	123
	.long	125
	.long	127
	.long	135
	.long	129
	.section	__DWARF,__debug_addr,regular,debug
Lsection_info0:
Lset11 = Ldebug_addr_end0-Ldebug_addr_start0 ## Length of contribution
	.long	Lset11
Ldebug_addr_start0:
	.short	5                               ## DWARF version number
	.byte	8                               ## Address size
	.byte	0                               ## Segment selector size
Laddr_table_base0:
	.quad	Lfunc_begin0
	.quad	Lfunc_begin1
	.quad	Lfunc_begin2
	.quad	Lfunc_begin3
	.quad	Lfunc_begin4
Ldebug_addr_end0:
	.section	__DWARF,__debug_names,regular,debug
Ldebug_names_begin:
Lset12 = Lnames_end0-Lnames_start0      ## Header: unit length
	.long	Lset12
Lnames_start0:
	.short	5                               ## Header: version
	.short	0                               ## Header: padding
	.long	1                               ## Header: compilation unit count
	.long	0                               ## Header: local type unit count
	.long	0                               ## Header: foreign type unit count
	.long	10                              ## Header: bucket count
	.long	12                              ## Header: name count
Lset13 = Lnames_abbrev_end0-Lnames_abbrev_start0 ## Header: abbreviation table size
	.long	Lset13
	.long	8                               ## Header: augmentation string size
	.ascii	"LLVM0700"                      ## Header: augmentation string
Lset14 = Lcu_begin0-Lsection_info       ## Compilation unit 0
	.long	Lset14
	.long	1                               ## Bucket 0
	.long	2                               ## Bucket 1
	.long	3                               ## Bucket 2
	.long	4                               ## Bucket 3
	.long	5                               ## Bucket 4
	.long	0                               ## Bucket 5
	.long	7                               ## Bucket 6
	.long	0                               ## Bucket 7
	.long	10                              ## Bucket 8
	.long	0                               ## Bucket 9
	.long	270123860                       ## Hash in Bucket 0
	.long	262750241                       ## Hash in Bucket 1
	.long	-1899289334                     ## Hash in Bucket 2
	.long	177683                          ## Hash in Bucket 3
	.long	5863364                         ## Hash in Bucket 4
	.long	5863364                         ## Hash in Bucket 4
	.long	5863396                         ## Hash in Bucket 6
	.long	1885305066                      ## Hash in Bucket 6
	.long	2090499946                      ## Hash in Bucket 6
	.long	193495088                       ## Hash in Bucket 8
	.long	-298455368                      ## Hash in Bucket 8
	.long	-298455368                      ## Hash in Bucket 8
	.long	129                             ## String in Bucket 0: Outer
	.long	111                             ## String in Bucket 1: Inner
	.long	56                              ## String in Bucket 2: _ZN1N2FYENS_5OuterE
	.long	51                              ## String in Bucket 3: N
	.long	76                              ## String in Bucket 4: Ez
	.long	41                              ## String in Bucket 4: ez
	.long	53                              ## String in Bucket 6: FY
	.long	79                              ## String in Bucket 6: _ZN1N2EzENS_5OuterE
	.long	106                             ## String in Bucket 6: main
	.long	119                             ## String in Bucket 8: int
	.long	99                              ## String in Bucket 8: _Z2Ezi
	.long	44                              ## String in Bucket 8: _Z2ezi
Lset15 = Lnames0-Lnames_entries0        ## Offset in Bucket 0
	.long	Lset15
Lset16 = Lnames1-Lnames_entries0        ## Offset in Bucket 1
	.long	Lset16
Lset17 = Lnames2-Lnames_entries0        ## Offset in Bucket 2
	.long	Lset17
Lset18 = Lnames3-Lnames_entries0        ## Offset in Bucket 3
	.long	Lset18
Lset19 = Lnames4-Lnames_entries0        ## Offset in Bucket 4
	.long	Lset19
Lset20 = Lnames5-Lnames_entries0        ## Offset in Bucket 4
	.long	Lset20
Lset21 = Lnames6-Lnames_entries0        ## Offset in Bucket 6
	.long	Lset21
Lset22 = Lnames7-Lnames_entries0        ## Offset in Bucket 6
	.long	Lset22
Lset23 = Lnames8-Lnames_entries0        ## Offset in Bucket 6
	.long	Lset23
Lset24 = Lnames9-Lnames_entries0        ## Offset in Bucket 8
	.long	Lset24
Lset25 = Lnames10-Lnames_entries0       ## Offset in Bucket 8
	.long	Lset25
Lset26 = Lnames11-Lnames_entries0       ## Offset in Bucket 8
	.long	Lset26
Lnames_abbrev_start0:
	.byte	1                               ## Abbrev code
	.byte	19                              ## DW_TAG_structure_type
	.byte	3                               ## DW_IDX_die_offset
	.byte	19                              ## DW_FORM_ref4
	.byte	4                               ## DW_IDX_parent
	.byte	19                              ## DW_FORM_ref4
	.byte	0                               ## End of abbrev
	.byte	0                               ## End of abbrev
	.byte	2                               ## Abbrev code
	.byte	46                              ## DW_TAG_subprogram
	.byte	3                               ## DW_IDX_die_offset
	.byte	19                              ## DW_FORM_ref4
	.byte	4                               ## DW_IDX_parent
	.byte	19                              ## DW_FORM_ref4
	.byte	0                               ## End of abbrev
	.byte	0                               ## End of abbrev
	.byte	3                               ## Abbrev code
	.byte	57                              ## DW_TAG_namespace
	.byte	3                               ## DW_IDX_die_offset
	.byte	19                              ## DW_FORM_ref4
	.byte	4                               ## DW_IDX_parent
	.byte	25                              ## DW_FORM_flag_present
	.byte	0                               ## End of abbrev
	.byte	0                               ## End of abbrev
	.byte	4                               ## Abbrev code
	.byte	46                              ## DW_TAG_subprogram
	.byte	3                               ## DW_IDX_die_offset
	.byte	19                              ## DW_FORM_ref4
	.byte	4                               ## DW_IDX_parent
	.byte	25                              ## DW_FORM_flag_present
	.byte	0                               ## End of abbrev
	.byte	0                               ## End of abbrev
	.byte	5                               ## Abbrev code
	.byte	36                              ## DW_TAG_base_type
	.byte	3                               ## DW_IDX_die_offset
	.byte	19                              ## DW_FORM_ref4
	.byte	4                               ## DW_IDX_parent
	.byte	25                              ## DW_FORM_flag_present
	.byte	0                               ## End of abbrev
	.byte	0                               ## End of abbrev
	.byte	0                               ## End of abbrev list
Lnames_abbrev_end0:
Lnames_entries0:
Lnames0:
	.byte	1                               ## Abbreviation code
	.long	149                             ## DW_IDX_die_offset
	.long	39                              ## DW_IDX_parent
	.byte	0                               ## End of list: Outer
Lnames1:
	.byte	1                               ## Abbreviation code
	.long	74                              ## DW_IDX_die_offset
	.long	60                              ## DW_IDX_parent
	.byte	1                               ## Abbreviation code
	.long	164                             ## DW_IDX_die_offset
	.long	0                               ## DW_IDX_parent
	.byte	0                               ## End of list: Inner
Lnames2:
	.byte	2                               ## Abbreviation code
	.long	93                              ## DW_IDX_die_offset
	.long	39                              ## DW_IDX_parent
	.byte	0                               ## End of list: _ZN1N2FYENS_5OuterE
Lnames3:
	.byte	3                               ## Abbreviation code
	.long	91                              ## DW_IDX_die_offset
	.byte	0                               ## DW_IDX_parent
                                        ## End of list: N
Lnames4:
	.byte	2                               ## Abbreviation code
	.long	121                             ## DW_IDX_die_offset
	.long	39                              ## DW_IDX_parent
	.byte	4                               ## Abbreviation code
	.long	182                             ## DW_IDX_die_offset
	.byte	0                               ## DW_IDX_parent
                                        ## End of list: Ez
Lnames5:
	.byte	4                               ## Abbreviation code
	.long	36                              ## DW_IDX_die_offset
	.byte	0                               ## DW_IDX_parent
                                        ## End of list: ez
Lnames6:
	.byte	2                               ## Abbreviation code
	.long	93                              ## DW_IDX_die_offset
	.long	39                              ## DW_IDX_parent
	.byte	0                               ## End of list: FY
Lnames7:
	.byte	2                               ## Abbreviation code
	.long	121                             ## DW_IDX_die_offset
	.long	39                              ## DW_IDX_parent
	.byte	0                               ## End of list: _ZN1N2EzENS_5OuterE
Lnames8:
	.byte	4                               ## Abbreviation code
	.long	210                             ## DW_IDX_die_offset
	.byte	0                               ## DW_IDX_parent
                                        ## End of list: main
Lnames9:
	.byte	5                               ## Abbreviation code
	.long	225                             ## DW_IDX_die_offset
	.byte	0                               ## DW_IDX_parent
                                        ## End of list: int
Lnames10:
	.byte	4                               ## Abbreviation code
	.long	182                             ## DW_IDX_die_offset
	.byte	0                               ## DW_IDX_parent
                                        ## End of list: _Z2Ezi
Lnames11:
	.byte	4                               ## Abbreviation code
	.long	36                              ## DW_IDX_die_offset
	.byte	0                               ## DW_IDX_parent
                                        ## End of list: _Z2ezi
	.p2align	2, 0x0
Lnames_end0:
.subsections_via_symbols
	.section	__DWARF,__debug_line,regular,debug
Lsection_line:
Lline_table_start0:
