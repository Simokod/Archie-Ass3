section .rodata
	format_string:	db "%s", 10, 0		; format string
	int_format:		db "%d", 10, 0		; sscanf integer format
	float_format:	db "%.2lf", 10, 0	; sscanf float format
	target_format: 	db "%.2f,%.2f", 10, 0				; target_printing_format
	drone_format: 	db "%d,%.2f,%.2f,%.2f,%d", 10, 0 	; drone_printing_format


section .data
	extern target_loc_x
	extern target_loc_y
	extern num_of_drones
	extern drone_stats_arr
	extern scheduler_struct

section .text
	extern printf
	extern resume
	global printer_func

	printer_func:
		call print_board
		mov ebx, scheduler_struct 			; gets a pointer to a scheduler struct
		call resume

	print_board:
		pushad
		push dword [target_loc_y]
		push dword [target_loc_x]
		push target_format
		call printf  						; printing target location
		add esp, 12

		mov eax, [drone_stats_arr] 			; getting pointer to array of drone stats
		mov ecx, 1
		print_drone_loop:
			shl ecx, 4 						; for computational purposes
			mov ebx, [eax+ecx-16] 			; eax(start of array), ecx(droneId*16) 
			shr ecx, 4 						; restoring originial value
 			push dword [ebx+12] 			; pushing num of targets destroyed 
 			push dword [ebx+8] 				; pushing angle
 			push dword [ebx+4] 				; pushing y-location
 			push dword [ebx] 				; pushing x-location
 			push ecx 						; pushing drone id
 			push drone_format
 			call printf
 			add esp, 24

 			inc ecx
			cmp ecx, [num_of_drones]
			jne print_drone_loop

		popad
		ret