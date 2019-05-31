section .rodata
	win_string: db "Drone id %d: I am a winner", 10, 0		; win_string

section .bss
	temp_num_int: resd 1 		; integer temp 
	curr_droneID: resd 1		; current drone ID
	curr_x: resd 1 				; current drones x-location
	curr_y: resd 1 				; current drones y-location
	curr_angle: resd 1 			; current drones angle
	distance: resd 1			; distance to move
	gamma: resd 1 				; gamma

section .data
	extern drone_stack_ptrs
	extern drone_stats_arr
	extern num_of_targets
	extern temp_num
	extern target_loc_x
	extern target_loc_y
	extern scheduler_struct
	extern target_struct

	extern shot_range
	extern field_of_view
	extern angle_max
	extern loc_max
	extern delta_angle_range
	extern minimum_delta_angle_val
	extern distance_max

	flag: db 1							; flag that signals if target is in fov

section .text
	extern printf
	extern end_game
	extern resume
	extern generate_distance
	extern generate_delta_angle
	global drone_func	

drone_func:
	call compute_currID 				; save current drone ID in curr_droneID
	call generate_delta_angle 			; save delta_angle in temp_num

	mov ecx, [curr_droneID] 			; saving drone ID in ecx
	shl ecx, 4 							; multypling by 16 (each drone stats array is 16 bytes)
	mov ebx, [drone_stats_arr] 			; saving pointer to drones stats array in ebx

	mov edx, [ebx+ecx-8] 				; moving current angle of current drone to edx
	mov [curr_angle], edx
	mov eax, [ebx+ecx-16] 				; saving current drones stats for easier access
	mov [curr_x], eax
	mov eax, [ebx+ecx-12] 
	mov [curr_y], eax

	fld dword [temp_num] 				; pushing delta_angle into x87
	fld dword [curr_angle] 				; pushing old angle into x87
	faddp st1, st0 						; calculating new angle, st(0) = new angle
	fst dword [temp_num] 				; storing new angle in temp_num
	fistp dword [temp_num_int] 			; storing new angle integer value for comparison
	call modulu_angle 					; making sure angle is in range(0,360)
	mov edx, [temp_num]
	mov [curr_angle], edx 				; updating new modulued angle

	call generate_distance 				; generate the distance the drone needs to move, and store in temp_num
	call move_drone 					; calculate new x and y locations for the drone
	call update_stats	 				; updates new locations in the drones stats array
	call may_destroy 					; drone tries to destroy target

	ret

update_stats:
	mov ecx, [curr_droneID]
	shl ecx, 4
	mov ebx, [drone_stats_arr]

	mov eax, [curr_x]
	mov [ebx+ecx-16], eax
	mov eax, [curr_y]
	mov [ebx+ecx-12], eax
	mov eax, [curr_angle]
	mov [ebx+ecx-8], eax

	ret

move_drone:
	pushad
	call calc_x 				; calculate new x value
	fld dword [curr_x]
	call modulu_location 		; make sure x is in range[0,100]

	call calc_y					; calculate new y value
	fld dword [curr_y]
	call modulu_location		; make sure y is in range[0,100]
	popad
	ret

calc_x:
	fld dword [curr_angle] 				; push alpha in x87
	push 180 							; pushing the number 180 on the stack to compute radians
	fidiv dword [esp]	 				; dividing angle by 180
	add esp, 4 							; remove pushed arg(180)
	fldpi  								; push pi into x87 in order to compute radians
	fmulp st1, st0						; st(0) alpha in radians
	fcos 								; compute cosinos of angle
	fld dword [temp_num] 				; st(0) = distance, st(1) = cosinos of alpha
	fmulp st1, st0						; calculate distance to move in x-axis
	fadd dword [curr_x] 				; add distnace to move in curr_x
	fstp dword [curr_x] 				; store new x-val
	ret

calc_y:
	fld dword [curr_angle] 				; push alpha in x87
	push 180 							; pushing the number 180 on the stack to compute radians
	fidiv dword [esp]	 				; dividing angle by 180
	add esp, 4 							; remove pushed arg(180)
	fldpi  								; push pi into x87 in order to compute radians
	fmulp st1, st0						; st(0) alpha in radians
	fsin 								; compute sinos of angle
	fld dword [temp_num]				; st(0) = distance, st(1) = sinos of alpha
	fmulp st1, st0 						; calculate distance to move in y-axis
	fadd dword [curr_y] 				; add distnace to move in curr_y
	fstp dword [curr_y] 				; store new y-val
	ret

			;; modulus
modulu_angle: 				; makes sure the angle is in the range[0,360]
	mov edx, [temp_num_int]
	cmp edx, 360
	jge .greater
	cmp edx, 0
	jl .lower
	ret
	.greater:
		fld dword [temp_num]
		fld dword [angle_max]
		fsubp st1, st0
		fstp dword [temp_num]
		ret
	.lower:
		fld dword [temp_num]
		fld dword [angle_max]
		faddp st1, st0
		fstp dword [temp_num]
		ret

modulu_location:
	fistp dword [temp_num_int]
	mov edx, [temp_num_int]
	cmp edx, 100
	jge .greater
	cmp edx, 0
	jl .lower
	ret
	.greater:
		fld dword [temp_num]
		fld dword [loc_max]
		fsubp st1, st0
		fstp dword [temp_num]
		ret
	.lower:
		fld dword [temp_num]
		fld dword [loc_max]
		faddp st1, st0
		fstp dword [temp_num]
		ret

may_destroy:
	call calc_gamma 				; calculate the gamma
	call is_in_fov 					; calculate if the target is in range
	cmp byte [flag], 1 				; check if the target is in range
	jne .finish 					; not flag

	call calc_distance 				; calculate the distance from the target
	cmp byte [flag], 1 				
	je resume_target 				; if not in range, resume to scheduler
	
	.finish:
		mov ebx, scheduler_struct 			; gets a pointer to a scheduler struct
		call resume
 					; target destroyed, check if game is finish, if not resume to target co-routine
	resume_target:
		mov ecx, [curr_droneID] 		; save id in ecx for computational purposes
		shl ecx, 4 						; multiply by 16 (each drones stats struct is 16 bytes)
		mov ebx, [drone_stats_arr] 		; getting pointer to array of stats
		inc dword [ebx+ecx-4] 			; increase num of targets destroyed
		mov eax, [num_of_targets] 		; for computational purposes
		cmp eax, [ebx+ecx-4] 			; check if the game is finished
		je finish_game

		mov ebx, target_struct 			; if not, resume to target
		call resume

		finish_game:
			push dword [curr_droneID]
			push win_string
			call printf 				; print winner string 
			add esp, 8

			call end_game 				; return to main in order to end the game

				;; calculates the gamma of the drone
calc_gamma:
	pushad
	fld dword [target_loc_x]
	fld dword [curr_x]
	fsubp st1, st0					; calculate x2-x1
	
	fld dword [target_loc_y]
	fld dword [curr_y]
	fsubp st1, st0					; calculate y2-y1
	fpatan 							; calculate arctan
	fstp dword [gamma]
	popad
	ret
				;; calculates if the target is inside the field of view of the drone
is_in_fov:
	mov byte [flag], 0 				; initilize flag
	fld dword [curr_angle] 			; push current angle of drone into x87
	push 180 						; pushing the number 180 on the stack to compute radians
	fidiv dword [esp]	 			; dividing angle by 180
	add esp, 4 						; remove pushed arg(180)
	fldpi  							; push pi into x87 in order to compute radians
	fmulp st1, st0					; st(0) alpha in radians

	fld dword [gamma] 				; push gamma into x87, st(0) = gamma, st(1) = alpha
	fsubp st1, st0  				; calculate gamma-alpha
	fabs							; calculate abs(gamma-alpha)
	fldpi 							; pushing pi into x87
	push 2 							; pushing 2 in order to multiply
	fimul dword [esp]				; multiply 2*pi, st(0) = 2*pi, st(1) = abs(gamma-alpha)
	add esp, 4 						; removing '2' from stack

	fsub st1 						; st(0) = 2*pi-abs, st(1) = abs(gamma-alpha)
	fcomi st0, st1 					; compare st(0) and st(1)
	jc cont 						; if (abs > 2*pi-abs), the difference between the angles is less then pi
	fxch 							; exchange st(0) and st(1), new values: st(0) = abs(gamma-alpha), and st(1) = 2*pi-abs
	cont:
		fld dword [field_of_view] 		; load beta into x87
		fxch 							; now, st(0) = abs, st(1) = beta
		fcomi st0, st1 					; check if the target is inside the field of view
		jnc .finish 						; if not, finish
		mov byte [flag], 1 					; if yes, signal true
		.finish:
			fstp dword [temp_num_int] 		; take out the trash value
			fstp dword [temp_num_int] 		; take out the trash value
			fstp dword [temp_num_int] 		; take out the trash value
			ret

calc_distance:
	mov byte [flag], 0
	fld dword [target_loc_y] 		; calculate (y2-y1)^2
	fld dword [curr_y]
	fsubp st1, st0
	fmul st0, st0

	fld dword [target_loc_x]		; calculate (x2-x1)^2
	fld dword [curr_x]
	fsubp st1, st0
	fmul st0, st0

	faddp st1, st0 					; add them
	fsqrt 							; calculate square root
	fld dword [shot_range]
	fxch 							; st(0) = sqrt, st(1) = d
	fcomi st0, st1
	jc .finish
	mov byte [flag], 1
	.finish:
		fstp dword [temp_num_int] 		; take out the trash value
		fstp dword [temp_num_int] 		; take out the trash value
		ret

compute_currID: 					; computes the current drone ID by finding the offset from the struct
	pushad
	sub ebx, [drone_stack_ptrs] 	; actual offset (ebx = current drone struct)
	add ebx, 16 					; adding 16 to address to considerate that IDs start from 1 (not from 0)
	shr ebx, 4 						; divide offset by 16
	mov [curr_droneID], ebx
	popad
	ret