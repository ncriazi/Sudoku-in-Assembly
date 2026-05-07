# Nick Riazi
# ncriazi
.text

##########################################
#  Part #1 Functions
##########################################

#a0 - pc_bg, a1 - pc_fg, a2- gc_bg, a3 - gc_fg, t0 - err_bg
checkColors:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, 4($sp) #err_bg
	
	#err_bg can not be the same as any other color
	beq $t0, $a0, error_return
	beq $t0, $a1, error_return
	beq $t0, $a2, error_return
	beq $t0, $a3, error_return
	
	#pc_fg *& gc_fg cannot be equal
	beq $a1, $a3, error_return
	
	#pc_fg & pc_bg cannot be the same color
	beq $a1, $a0, error_return
	
	#gc_bg & gc_fg cannot be the same color
	beq $a2, $a3, error_return
	
	#goal get 0xFA35	
	#makes first four bits 1111 0000 -> or combines for -> 1111 1010
	sll $t1, $a0, 4 
	or $t1, $t1, $a1
	
	#second half
	sll $t2, $a2, 4
	or $t2, $t2, $a3
	
	#to get full 16 value, 1111 1010 etc...
	sll $t1, $t1, 8
	or $v0, $t1, $t2
	
	#to return err_bg
	move $v1, $t0
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

	error_return:
		li $v0, 0xFFFF
		li $v1, 0xFF
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	

#a0 - r, a1 - c, a2 - val, a3 - cellColor
setCell:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# r < 0 || r >=9
	bltz $a0, error_setCell
	bge $a0, 9, error_setCell
	
	#c < 0 || c >= 9
	bltz $a1, error_setCell
	bge $a1, 9, error_setCell
	
	#val < -1 || val > 9
	li $t0, -1
	blt $a2, $t0, error_setCell
	bgt $a2, 9, error_setCell
	
	# (r * 9 + c) * 2(size of byte)
	li $t0, 9
	mul $t1, $a0, $t0
	add $t1, $t1, $a1
	sll $t1, $t1, 1
	
	#calculate MMIO address
	lui $t2, 0xffff
	add $t2, $t2, $t1
	
	
	#if val is 0 -> set null
	beq $a2, $zero, set_null
	
	#if val is -1 -> only color modified
	li $t0, -1
	beq $a2, $t0, set_color_only
	
	#AsCII conversion
	addi $t3, $a2, 48
	
	#Byte 0 - ASCII character
	sb $t3, 0($t2)
	
	#Byte 1 - Color byte
	sb $a3, 1($t2)
	
	#returns - on success
	li $v0, 0
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	set_null:
		#storing null
		sb $zero, 0($t2)
		
		sb $a3, 1($t2)
		
		li $v0, 0
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	set_color_only:
		sb $a3, 1($t2)
		
		
		li $v0, 0
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	error_setCell:
		li $v0, -1
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra

#a0 - r, a1 - c
getCell:
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# r < - || r >= 9
	bltz $a0, error_getCell
	bge $a0, 9, error_getCell
	
	# c < 0 || c >= 9
	bltz $a1, error_getCell
	bge $a1, 9, error_getCell
	
	#(r * 9 + c) * 2 (size)
	li $t0, 9
	mul $t1, $a0, $t0
	add $t1, $t1, $a1
	sll $t1, $t1, 1
	
	#calc mmio address
	lui $t2, 0xffff
	add $t2, $t2, $t1
	
	#ACII char at byte 0, color byte at byte 1
	lbu $t3, 0($t2)
	lbu $t4, 1($t2)
	
	#if null -> return empty
	beq $t3, $zero, return_null_char
	
	#in all other cases return error
	li $t5, 48
	blt $t3, $t5, error_getCell
	
	li $t5, 57
	bgt $t3, $t5, error_getCell
	
	#to get value & return (cellColor, value)
	addi $v1, $t3, -48
	move $v0, $t4
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
	
	return_null_char:
		#load w/ null, return (cellColor, 0)
		move $v0, $t4
		li $v1, 0
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	error_getCell:
		#return (0xFF, -1)
		li $v0, 0xFF
		li $v1, -1
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra

reset:
	addi $sp, $sp, -36
	sw $ra, 32($sp)
	sw $s0, 28($sp)
	sw $s1, 24($sp)
	sw $s2, 20($sp)
	sw $s3, 16($sp)
	sw $s4, 12($sp)
	sw $s5, 8($sp)
	sw $s6, 4($sp)
	sw $s7, 0($sp)

	move $s0, $a0
	move $s1, $a1
	move $s2, $a2
	
	#err_bg > 0xf -> error
	li $t0, 0xF
	bgt $s1, $t0, error_reset
	
	# numConflicts < 0 
	bltz $s2, reset_clear_all
	#  numConflicts == 0
	beq $s2, $zero, reset_to_preset
	#else
	j reset_conflicts

	reset_clear_all:
		li $s3, 0

	reset_clear_loop:
		#loop through all 81 cells
		li $t0, 81
		bge $s3, $t0, reset_clear_done
		#get r & c 
		li $t0, 9
		div $s3, $t0
		mflo $a0
		mfhi $a1
		
		#call setCell with necessary parameters
		li $a2, 0
		li $a3, 0xf0
		jal setCell
		
		#increment cell count
		addi $s3, $s3, 1
		j reset_clear_loop
	
	reset_clear_done:
		#return 0 on success
		li $v0, 0
		j reset_done

	reset_to_preset:
		#reset to preset cells, reset colors bsed on curColor
		#game cells ASCII valeus removed (set to null)
		
		#extracting preset fg & game fg from curColor
		srl $t0, $s0, 8
		andi $t0, $t0, 0xFF

		andi $t2, $t0, 0xF

		andi $t3, $s0, 0xFF

		andi $t5, $t3, 0xF

		move $s3, $t2
		move $s4, $t5

		li $s5, 0

	reset_preset_loop:
		#achieve the parameters for getCell
		li $t0, 81
		bge $s5, $t0, reset_preset_done

		li $t0, 9
		div $s5, $t0
		mflo $a0
		mfhi $a1

		jal getCell
		#check cellColor

		li $t0, 0xFF
		beq $v0, $t0, error_reset

		andi $t8, $v0, 0xF

		beq $t8, $s3, reset_preset_cell
		beq $t8, $s4, reset_game_cell
		j error_reset

	reset_preset_cell:
		#achieve the parameters for setCell
		li $t0, 9
		div $s5, $t0
		mflo $a0
		mfhi $a1

		li $a2, -1

		srl $t0, $s0, 8
		andi $a3, $t0, 0xFF

		jal setCell

		addi $s5, $s5, 1
		j reset_preset_loop

	reset_game_cell:
		#parameters for setCell
		li $t0, 9
		div $s5, $t0
		mflo $a0
		mfhi $a1

		li $a2, 0

		andi $a3, $s0, 0xFF

		jal setCell

		addi $s5, $s5, 1
		j reset_preset_loop

	reset_preset_done:
		#success
		li $v0, 0
		j reset_done

	reset_conflicts:
		#examine board in colum-major order
		#for preset/game cells marked with err_bg
		#first numConflcits num of / cells are reset to
		#color specified in cur color
		#error occurs when numConflicts cells are not found
		srl $t0, $s0, 8
		andi $t0, $t0, 0xFF
		andi $t1, $t0, 0xF

		andi $t2, $s0, 0xFF
		andi $t3, $t2, 0xF

		move $s3, $t1
		move $s4, $t3

		li $s5, 0

		li $s6, 0

	reset_conflict_loop_col:
		li $t0, 9
		bge $s6, $t0, reset_conflict_check_found
		li $s7, 0

	reset_conflict_loop_row:
		li $t0, 9
		bge $s7, $t0, reset_conflict_next_col

		move $a0, $s7
		move $a1, $s6
		jal getCell

		li $t0, 0xFF
		beq $v0, $t0, error_reset

		srl $t6, $v0, 4
		andi $t6, $t6, 0xF

		andi $t7, $v0, 0xF

		bne $t6, $s1, reset_conflict_skip_cell

		beq $t7, $s3, reset_conflict_found_preset
		beq $t7, $s4, reset_conflict_found_game
		j error_reset

	reset_conflict_found_preset:
		move $a0, $s7
		move $a1, $s6
		li $a2, -1

		srl $t0, $s0, 8
		andi $a3, $t0, 0xFF

		jal setCell

		addi $s5, $s5, 1

		beq $s5, $s2, reset_conflict_success

		j reset_conflict_skip_cell

	reset_conflict_found_game:
		move $a0, $s7
		move $a1, $s6
		li $a2, -1

		andi $a3, $s0, 0xFF

		jal setCell

		addi $s5, $s5, 1

		beq $s5, $s2, reset_conflict_success

	reset_conflict_skip_cell:
		addi $s7, $s7, 1
		j reset_conflict_loop_row

	reset_conflict_next_col:
		addi $s6, $s6, 1
		j reset_conflict_loop_col

	reset_conflict_check_found:
		bne $s5, $s2, error_reset

	reset_conflict_success:
    		li $v0, 0
    		j reset_done

	error_reset:
		li $v0, -1

	reset_done:
		lw $ra, 32($sp)
		lw $s0, 28($sp)
		lw $s1, 24($sp)
		lw $s2, 20($sp)
		lw $s3, 16($sp)
		lw $s4, 12($sp)
		lw $s5, 8($sp)
		lw $s6, 4($sp)
		lw $s7, 0($sp)
		addi $sp, $sp, 36
		jr $ra

##########################################
#  Part #2 Function
##########################################
#a0 - char[] filename, a1 - boardColors
readFile:
	addi $sp, $sp, -40
	sw $ra, 36($sp)
	sw $s0, 32($sp)
	sw $s1, 28($sp)
	sw $s2, 24($sp)
	sw $s3, 20($sp)
	sw $s4, 16($sp)
	sw $s5, 12($sp)
	sw $s6, 8($sp)
	
	move $s0, $a0
	move $s1, $a1
	
	#reset the board
	move $a0, $s1
	li $a1, -1
	li $a2, -1
	jal reset
	
	#error check
	bltz $v0, error_readFile
	
	#open file
	#file name at $a0, a1 - flag, a2 - must be set to 0
	#syscall open file -> 13
	move $a0, $s0
	li $a1, 0
	li $v0, 13
	syscall
	
	#file descriptor, fail if fd < 0
	move $s2, $v0
	bltz $s2, error_readFile
	
	#unique filled counter = 0
	li $s3, 0
	
	read_loop:
		#syscall read(fd, buffer, 5) - a0, a1, a2
		move $a0, $s2	
		addi $a1, $sp, 0
		li $a2, 5
		li $v0, 14
		syscall
		
		move $s4, $v0
		
		#if bytes neg -> read_error
		bltz $s4, close_and_error
		
		#zero bytes -> EOF
		beq $s4, $zero, read_done
		
		#getBoardInfo(line, 0) - > row, col 
		#a0 & a1
		
		addi $a0, $sp, 0
		li $a1, 0
		jal getBoardInfo
		
		move $s5, $v0
		move $s6, $v1
		
		#error flag (-1, -1)
		li $t0, -1
		beq $s5, $t0, close_and_error
		
		#getCell(row, col) - a0, a1
		move $a0, $s5
		move $a1, $s6
		jal getCell
		
		#cellColor, cell value
		move $t2, $v0
		move $t3, $v1
		
		#error check
		li $t4, 0xFF
		beq $t2, $t4, close_and_error
		
		#getBoardInfo(line, 1) -> value, type
		addi $a0, $sp, 0
		li $a1, 1
		jal getBoardInfo
		
		
		move $t4, $v0
		move $t5, $v1
		
		# (-1, -1) means error
		li $t6, -1
		beq $t4, $t6, close_and_error
		
		#check if value changed, if existing cell value != new value
		bne $t3, $t4, increment_unique
		
		j continue_set
	
	increment_unique:
		addi $s3, $s3, 1
		
	continue_set:
		
		#setCell(row col, value)
		move $a0, $s5
		move $a1, $s6
		move $a2, $t4
		
		#check type
		li $t6, 80
		beq $t5, $t6, set_preset_cell
		
		#Game Cell (type !+ preset)
		andi $a3, $s1, 0xFF
		jal setCell
		
		bltz $v0, close_and_error
		j read_loop
		
	#preset cell color handled
	set_preset_cell:
		srl $t7, $s1, 8
		andi $a3, $t7, 0xFF
		jal setCell
		
		bltz $v0, close_and_error
		j read_loop
	
	#EOF Success
	read_done:
		#close file
		move $a0, $s2
		li $v0, 16
		syscall
		
		#return num of unq cells
		move $v0, $s3
		
		
		lw $ra, 36($sp)
		lw $s0, 32($sp)
		lw $s1, 28($sp)
		lw $s2, 24($sp)
		lw $s3, 20($sp)
		lw $s4, 16($sp)
		lw $s5, 12($sp)
		lw $s6, 8($sp)
		addi $sp, $sp, 40
		jr $ra
	
	#Error handling: close file then return -1
	close_and_error:
		move $a0, $s2
		li $v0, 16
		syscall
	
	error_readFile:
		li $v0, -1
		
		lw $ra, 36($sp)
		lw $s0, 32($sp)
		lw $s1, 28($sp)
		lw $s2, 24($sp)
		lw $s3, 20($sp)
		lw $s4, 16($sp)
		lw $s5, 12($sp)
		lw $s6, 8($sp)
		addi $sp, $sp, 40
		jr $ra
		
		
		
		
		
		
		
##########################################
#  Part #3 Functions
##########################################

#a0 -row, a1 - col, a2 value, a3 flag
rowColCheck:
	addi $sp, $sp, -24
	sw $ra, 20($sp)
	sw $s0, 16($sp)
	sw $s1, 12($sp)
	sw $s2, 8($sp)
	sw $s3, 4($sp)
	sw $s4, 0($sp)
	
	move $s0, $a0
	move $s1, $a1
	move $s2, $a2
	move $s3, $a3
	
	#error checking
	# row < 0 || row >= 9
	bltz $s0, error_rowColCheck
	bge $s0, 9, error_rowColCheck
	
	#col < 0 || col >= 9
	bltz $s1, error_rowColCheck
	bge $s1, 9, error_rowColCheck
	
	#value < -1 || value > 9
	li $t0, -1
	blt $s2, $t0, error_rowColCheck
	bgt $s2, 9, error_rowColCheck
	
	#devide mode check row or column, 0 or else
	beq $s3, $zero, check_row
	j check_col
	
	check_row:
		li $s4, 0
	
	check_row_loop:
		li $t1, 9
		bge $s4, $t1, no_conflict
		
		beq $s4, $s1, skip_row_cell
		
		#call getCell(row, t0)
		move $a0, $s0
		move $a1, $s4
		jal getCell
		
		#if error returned
		li $t1, 0xFF
		beq $v0, $t1, error_rowColCheck
		
		#compare cell value to targ value
		bne $v1, $s2, skip_row_cell
		
		#Match found -> return (row, matching col)
		move $v0, $s0
		move $v1, $s4
		j rowColCheck_done
	
	skip_row_cell:
		addi $s4, $s4, 1
		j check_row_loop
	
	check_col:
		li $s4, 0
	
	check_col_loop:
		li $t1, 9
		bge $s4, $t1, no_conflict
		
		beq $s4, $s0, skip_col_cell
		
		#call getCell again
		move $a0, $s4
		move $a1, $s1
		
	
		jal getCell
		
		
		#error
		li $t1, 0xFF
		beq $v0, $t1, error_rowColCheck
		
		bne $v1, $s2, skip_col_cell
		
		move $v0, $s4
		move $v1, $s1
		j rowColCheck_done
	
	skip_col_cell:
		addi $s4, $s4, 1
		j check_col_loop
	
	#return section
	no_conflict:
		li $v0, -1
		li $v1, -1
		j rowColCheck_done
	
	error_rowColCheck:
		li $v0, -1
		li $v1, -1
	
	rowColCheck_done:
		lw $ra, 20($sp)
		lw $s0, 16($sp)
		lw $s1, 12($sp)
		lw $s2, 8($sp)
		lw $s3, 4($sp)
		lw $s4, 0($sp)
		addi $sp, $sp, 24
		jr $ra

#a0 = row, a1 = col, a2 = value
squareCheck:
	addi $sp, $sp, -36
	sw $ra, 32($sp)
	sw $s0, 28($sp)
	sw $s1, 24($sp)
	sw $s2, 20($sp)
	sw $s3, 16($sp)
	sw $s4, 12($sp)
	sw $s5, 8($sp)
	sw $s6, 4($sp)
	sw $s7, 0($sp)
	
	move $s0, $a0
	move $s1, $a1
	move $s2, $a2
	
	#error checkin, row < 0 || row >= 9
	bltz $s0, error_squareCheck
	li $t0, 9
	bge $s0, $t0, error_squareCheck
	
	# col < 0 || col >= 9
	bltz $s1, error_squareCheck
	bge $s1, $t0, error_squareCheck
	
	#value < -1 || value > 9
	li $t0, -1
	blt $s2, $t0, error_squareCheck
	li $t0, 9
	bgt $s2, $t0, error_squareCheck
	
	li $t0, 3
	
	div $s0, $t0
	mflo $t1
	mul $s3, $t1, $t0
	addi $s5, $s3, 3
	
	div $s1, $t0
	mflo $t1
	mul $s7, $t1, $t0
	addi $s6, $s7, 3
	
	loop_sq_row:
		bge $s3, $s5, end_squareCheck_no_conflict
		
		move $s4, $s7
		
	loop_sq_col:
		bge $s4, $s6, advance_sq_row
		
		bne $s3, $s0, check_cell
		bne $s4, $s1, check_cell
		j advance_sq_col
		
	check_cell:
		move $a0, $s3
		move $a1, $s4
		jal getCell
		
		li $t0, -1
		beq $v0, $t0, advance_sq_col
		
		beq $v1, $s2, found_conflict
	
	advance_sq_col:
		addi $s4, $s4, 1
		j loop_sq_col
	
	advance_sq_row:
		addi $s3, $s3, 1
		j loop_sq_row
	
	found_conflict:
		move $v0, $s3
		move $v1, $s4
		j exit_squareCheck
	
	end_squareCheck_no_conflict:
		li $v0, -1
		li $v1, -1
		j exit_squareCheck
	
	error_squareCheck:
		li $v0, -1
		li $v1, -1
	
	exit_squareCheck:
		lw $ra, 32($sp)
		lw $s0, 28($sp)
		lw $s1, 24($sp)
		lw $s2, 20($sp)
		lw $s3, 16($sp)
		lw $s4, 12($sp)
		lw $s5, 8($sp)
		lw $s6, 4($sp)
		lw $s7, 0($sp)
		addi $sp, $sp, 36
		jr $ra
#a0 - row, a1 - col, a2 value, a3 err_color, flag on stack
check:
	addi $sp, $sp, -32
	sw $ra, 28($sp)
	sw $s0, 24($sp)
	sw $s1, 20($sp)
	sw $s2, 16($sp)
	sw $s3, 12($sp)
	sw $s4, 8($sp)
	sw $s5, 4($sp)
	
	move $s0, $a0
	move $s1, $a1
	move $s2, $a2
	move $s3, $a3
	
	lw $s4, 32($sp)
	
	li $s5, 0
	
	#error checking
	# row < 0 || row >= 9
	bltz $s0, error_check
	li $t0, 9
	bge $s0, $t0, error_check
	
	#col < 0 || col >= 9
	bltz $s1, error_check
	bge $s1, $t0, error_check
	
	#value < -1 || value > 9
	li $t0, -1
	blt $s2, $t0, error_check
	li $t0, 9
	bgt $s2, $t0, error_check
	
	#err_color > 0xF
	li $t0, 0xF
	bgt $s3, $t0, error_check
	
	#call rowcolcheck(row, col, value, flag=0)
	move $a0, $s0
	move $a1, $s1
	move $a2, $s2
	li $a3, 0
	jal rowColCheck
	
	li $t0, -1
	beq $v0, $t0, do_col_check
	
	addi $s5, $s5, 1
	
	beqz $s4, do_col_check
	
	move $a0, $v0
	move $a1, $v1
	jal color_conflict_cell
	
	
	do_col_check:
		#rowColCheck(row, col, value, flag =1)
		move $a0, $s0
		move $a1, $s1
		move $a2, $s2
		li $a3, 1
		jal rowColCheck
		
		li $t0, -1
		beq $v0, $t0, do_square_check
		
		addi $s5, $s5, 1
		beqz $s4, do_square_check
		
		move $a0, $v0
		move $a1, $v1
		jal color_conflict_cell
		
	do_square_check:
		#squareCheck(row, col, value)
		move $a0, $s0
		move $a1, $s1
		move $a2, $s2
		jal squareCheck
		
		li $t0, -1
		beq $v0, $t0, check_done
		
		addi $s5, $s5, 1
		beqz $s4, check_done
		
		move $a0, $v0
		move $a1, $v1
		jal color_conflict_cell
		
	check_done:
		move $v0, $s5
		j exit_check
	
	error_check:
		li $v0, -1
	
	exit_check:
		lw $ra, 28($sp)
		lw $s0, 24($sp)
		lw $s1, 20($sp)
		lw $s2, 16($sp)
		lw $s3, 12($sp)
		lw $s4, 8($sp)
		lw $s5, 4($sp)
		addi $sp, $sp, 32
		jr $ra
	
	color_conflict_cell:
		addi $sp, $sp, -12
		sw $ra, 8($sp)
		sw $a0, 4($sp)
		sw $a1, 0($sp)

		jal getCell
		
		andi $t0, $v0, 0x0F
		sll $t1, $s3, 4
		or $a3, $t1, $t0
		
		lw $a0, 4($sp)
		lw $a1, 0($sp)
		move $a2, $v1

		jal setCell
		
		
		lw $ra, 8($sp)
		addi $sp, $sp, 12
		jr $ra

#a0 - move, a1 - playerColors, a2 - err_color
makeMove:
	addi $sp, $sp, -40
	sw $ra, 36($sp)
	sw $s0, 32($sp)
	sw $s1, 28($sp)
	sw $s2, 24($sp)
	sw $s3, 20($sp)
	sw $s4, 16($sp)
	sw $s5, 12($sp)
	sw $s6, 8($sp)
	
	move $s0, $a0
	move $s1, $a1
	move $s2, $a2
	
	move $a0, $s0
	li $a1, 0
	jal getBoardInfo
	
	move $s3, $v0
	move $s4, $v1
	
	li $t0, -1
	beq $s3, $t0, ret_invalid_move
	
	move $a0, $s0
	li $a1, 1
	jal getBoardInfo
	
	move $s5, $v0
	move $s6, $v1
	
	li $t0, -1
	beq $s5, $t0, ret_invalid_move
	
	move $a0, $s3
	move $a1, $s4
	jal getCell
	
	move $t0, $v0
	move $t1, $v1
	
	beq $t1, $s5, no_action
	
	beq $t1, $zero, check_move_zero
	j check_preset
	
	check_move_zero:
		beq $s5, $zero, no_action
	
	check_preset:
		andi $t2, $t0, 0xF
		
		srl $t3, $s1, 8
		andi $t3, $t3, 0xF
		
		beq $t2, $t3, ret_invalid_move
		
		beq $s5, $zero, clear_cell
		
		move $a0, $s3
		move $a1, $s4
		move $a2, $s5
		move $a3, $s2
		li $t0, 1
		sw $t0, 4($sp)
		jal check
		
		move $t4, $v0
		
		bne $t4, $zero, move_conflicts
		
		move $a0, $s3
		move $a1, $s4
		move $a2, $s5
		andi $a3, $s1, 0xFF
		jal setCell
		
		li $v0, 0
		li $v1, -1
		j makeMove_done
		
	clear_cell:
		move $a0, $s3
		move $a1, $s4
		li $a2, 0
		andi $a3, $s1, 0xFF
		jal setCell
		
		li $v0, 0
		li $v1, 1
		j makeMove_done
		
	no_action:
		li $v0, 0
		li $v1, 0
		j makeMove_done
	
	move_conflicts:
		li $v0, -1
		move $v1, $t4
		j makeMove_done
	
	ret_invalid_move:
		li $v0, -1
		li $v1, 0
		j makeMove_done
	
	makeMove_done:
		lw $ra, 36($sp)
		lw $s0, 32($sp)
		lw $s1, 28($sp)
		lw $s2, 24($sp)
		lw $s3, 20($sp)
		lw $s4, 16($sp)
		lw $s5, 12($sp)
		lw $s6, 8($sp)
		addi $sp, $sp, 40
		jr $ra
