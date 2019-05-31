
section .data
	extern num_of_drones
	extern print_rate
	extern drone_stack_ptrs
	extern printer_struct
	extern resume

section .text
	global scheduler_func

scheduler_func:
	mov ecx, 1				; for loop purposes
	mov eax, 0
	main_loop:
		mov ebx, [drone_stack_ptrs] ; getting current drones struct
		mul dword [num_of_drones] 	; multiplying num of drones by number of iterations
		sub ecx, eax 				; for computation purposes
		shl ecx, 3 					; for computation purposes
		add ebx, ecx 				; adding ecx*8

		shr ecx, 3 					; restoring original value
		add ecx, eax				; restoring original value

		sub ebx, 8
		call resume 				; calling drone_func

		inc ecx
		mov eax, ecx
		mov edx, 0
		div dword [print_rate] 			; i % print_rate

		cmp edx, 0 						; checking if need to print
		jne continue 					; if not, continue
		mov ebx, printer_struct
		call resume 					; printing board

	continue:
		mov eax, ecx
		mov edx, 0
		div dword [num_of_drones]		; i % num_of_drones
		jmp main_loop

