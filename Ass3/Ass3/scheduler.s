
section .data
	extern num_of_drones
	extern print_rate
	extern drone_stack_ptrs
	extern printer_struct
	extern resume
	;print_counter: dd 1				; counting steps done in order to print

section .text
	global scheduler_func

scheduler_func:
	mov ecx, 1					; drone counter
	mov edx, 1 					; print counter
	mov ebx, [drone_stack_ptrs] ; getting current drones struct
	main_loop:
		call resume 					; calling drone_func
		cmp edx, [print_rate]			; checking if need to print
		jne continue 					; if not, continue

		pushad
		mov ebx, printer_struct		
		call resume 					; printing board
		popad
		mov edx, 0 						; reset counter

	continue:
		inc ecx
		inc edx
		add ebx, 8 						; move pointer to next drones struct
		cmp ecx, [num_of_drones] 		; checking if finished iteration over drones
		jng main_loop 					; if not - continue loop
		
		mov ecx, 1 						; if yes - reset counter
		mov ebx, [drone_stack_ptrs] 	; point ebx to first drone struct
		jmp main_loop

