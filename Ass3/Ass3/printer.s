section .rodata
	format_string:  db "%s", 10, 0       		; format string
	newLine:		db "", 0					; new line char
	target_format: 	db "%.2f, %.2f", 10, 0					; target_printing_format
	drone_format: 	db "%d, %.2f, %.2f, %.2f, %d", 10, 0 	; drone_printing_format

section .data
	extern target_loc_x
	extern target_loc_y
	extern num_of_drones
	extern drone_stats_arr
	extern scheduler_struct

	curr_ID: dd 0 				; current drone ID in loop
	q_print: dq 1				; var used to print quadwords

section .text
	extern printf
	extern resume
	global printer_func

	printer_func:
		fld dword [target_loc_x]
		fstp qword [q_print]
		push dword [q_print+4] 				; pushing x location in to stack
		push dword [q_print]

		fld dword [target_loc_y]
		fstp qword [q_print]
		push dword [q_print+4] 				; pushing y location in to stack
		push dword [q_print]

		push target_format
		call printf  						; printing target location
		add esp, 20

		mov dword [curr_ID], 1
		print_drone_loop:
			mov eax, [drone_stats_arr] 			; getting pointer to array of drone stats
			mov ecx, [curr_ID]
			shl ecx, 4 						; for computational purposes
			mov ebx, eax
			add ebx, ecx
			sub ebx, 16 					; eax(start of array), ecx(droneId*16) 
			shr ecx, 4 						; restoring originial value
 			push dword [ebx+12] 			; pushing num of targets destroyed 

 			fld dword [ebx+8] 				
			fstp qword [q_print]
			push dword [q_print+4] 			; pushing angle
			push dword [q_print]

 			fld dword [ebx+4] 			
			fstp qword [q_print]
			push dword [q_print+4] 			; pushing y-location
			push dword [q_print]

 			fld dword [ebx] 			
			fstp qword [q_print]
			push dword [q_print+4] 			; pushing x-location
			push dword [q_print]

 			push ecx 						; pushing drone id
 			push drone_format
 			call printf
 			add esp, 36

			mov ecx, [curr_ID]
 			inc ecx
			mov [curr_ID], ecx
			cmp ecx, [num_of_drones]
			jng print_drone_loop

	    pushad
	    push newLine
	    push format_string    ; print new line
	    call printf
	    add esp, 8            
	    popad

		mov ebx, scheduler_struct 			; gets a pointer to a scheduler struct
		call resume
		jmp printer_func