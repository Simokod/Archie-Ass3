section .data
	extern scheduler_struct
	extern generate_loc
	extern target_loc_x
	extern target_loc_y
	extern temp_num

section .text
	extern resume
	global target_func

	target_func:
		call create_target
		mov ebx, scheduler_struct 			; gets a pointer to a scheduler struct
		call resume

	create_target:
		pushad
		call generate_loc
		mov eax, [temp_num]
		mov [target_loc_x], eax 			; generating x location of target

		call generate_loc
		mov eax, [temp_num]
		mov [target_loc_y], eax 			; generating y location of target

		popad
		ret