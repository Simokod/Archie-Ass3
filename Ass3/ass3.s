section .rodata
	global angle_max
	global loc_max
	global delta_angle_range
	global minimum_delta_angle_val
	global distance_max
	
	format_string:		db "%s", 10, 0		; format string
	int_format:			db "%d", 10, 0		; sscanf integer format
	float_format:		db "%.2fe", 10, 0	; sscanf float format
	args_error:   		db "Error: Wrong amount of arguments", 0
	loc_max:				dd 100.0
	angle_max: 				dd 360.0
	delta_angle_range: 		dd 120.0
	minimum_delta_angle_val:dd 60.0
	distance_max:			dd 50.0
	SHORT_MAX:				dd 65535.0
	STKSIZE equ 16*1024
	CODEP equ 0 					; offset of pointer to co-routine function in co-routine struct
	SPP equ 4						; offset of pointer to co-routine stack in co-routine struct 


section .bss
	global num_of_drones
	global field_of_view
	global shot_range
	global num_of_targets

	global print_rate
	global drone_stack_ptrs
	global drone_stats_arr
	global printer_struct
	global scheduler_struct
	global target_struct
	global target_loc_x
	global target_loc_y
	global temp_num

	num_of_drones : resd 1 			; number of drones in the game
	num_of_targets: resd 1			; number of targets needed to be destroyed in order to win
	print_rate: resd 1				; number of turns between printing
	field_of_view: resq 1			; angle of drone field-of-view
	shot_range: resq 1				; maximum distance that allows to destroy a target
	curr_random: resw 1 			; saving current seed

	str_ptr: resd 1					; pointer to string to sscanf
	arg_ptr: resd 1					; pointer to arguement variable

	drone_stack: resd 1				; array of drone stacks
	drone_stack_ptrs: resd 1		; array of drones pointers to stack and drone_func
	drone_stats_arr: resd 1			; array containg info about drones(locations and score)

	scheduler_struct: resd 2		; struct of scheduler
	scheduler_stack: resd STKSIZE 	; stack of scheduler
	printer_struct: resd 2			; struct of printer
	printer_stack: resd STKSIZE 	; stack of printer
	target_struct: resd 2			; struct of target
	target_stack: resd STKSIZE		; stack of target

	curr_struct: resd 1 			; pointer to current co-routine struct
	target_loc_x: resd 1			; current location of target
	target_loc_y: resd 1			; current location of target
	curr_drone: resd 1 				; index of current drone
	SPT: resd 1 					; temporary stack pointer
	SPMAIN: resd 1 					; stack pointer of main
	temp_num: resd 1				; temporary variable to save values

section .data
	carry_flag_value: db 0			; initial carry_flag_value 

section .text
	extern stdout
	extern printf
	extern calloc
	extern free
	extern sscanf
	extern strtof				;;;;;;;;;;;;
	extern atof
	extern drone_func
	extern printer_func
	extern target_func
	extern scheduler_func

	global main
	global generate_loc
	global generate_delta_angle
	global generate_distance
	global resume
	global end_game

main:
	push ebp					; backup last activation frame
	mov ebp, esp				; save current activation frame
	pushad						; backup registers

	FINIT							; initializing x87
	mov eax, [ebp+12] 				; pointer to argv[]

	mov ebx, [eax+4] 				; pointer to argv[1]
	mov dword [str_ptr], ebx 		; storing in str_ptr for sscanf
	mov ecx, num_of_drones 			; pushing arg for sscanf
	call read_int 					; reading num_of_drones

	mov ebx, [eax+8]
	mov dword [str_ptr], ebx
	mov ecx, num_of_targets
	call read_int 					; reading number of targets

	mov ebx, [eax+12]
	mov dword [str_ptr], ebx
	mov ecx, print_rate
	call read_int 					; reading print rate

	mov ebx, [eax+16]
	mov dword [str_ptr], ebx
	mov ecx, field_of_view
	call read_float					; reading field-of-view
asd:
	mov ebx, [eax+20]
	mov dword [str_ptr], ebx
	mov ecx, shot_range
	call read_float					; reading shot_range

	fld dword [ecx]
	fstp dword [ecx]

	mov ebx, [eax+24]
	mov dword [str_ptr], ebx
	mov ecx, curr_random
	call read_int					; reading seed

after_reading:
	pushad

	push STKSIZE
	push dword [num_of_drones] 				; callocating stack for all drones
	call calloc
	add esp, 8
	mov dword [drone_stack], eax

	push 8
	push dword [num_of_drones] 				; callocating pointer array to drone stacks
	call calloc
	add esp, 8
	mov dword [drone_stack_ptrs], eax
	popad

	call init_stack_ptrs

	push 16 								; 16 bytes for each drone(x(4), y(4), angle(4), num_of_targets(4))
	push dword [num_of_drones] 				; callocating array of pointers to drones stats
	call calloc
	add esp, 8
	mov dword [drone_stats_arr], eax


	call init_target
	call init_scheduler
	call init_printer

	mov ecx, dword [num_of_drones]
	create_drones_loop:
		call init_drone
		loop create_drones_loop, ecx

		; starting scheduler by first saving main state and calling do_resume

	pushfd
	pushad 								; save registers of main ()
	mov [SPMAIN], esp 					; save ESP of main ()
	mov ebx, scheduler_struct 			; gets a pointer to a scheduler struct
	jmp do_resume 
	ret

read_int:
	pushad
	push ecx
	push int_format
	push dword [str_ptr]
	call sscanf
	add esp, 12
	popad
	ret 

read_float:
	pushad
	push dword [str_ptr]
	call atof
strof:
	add esp, 4
	mov [temp_num], eax
	popad
	ret 


init_stack_ptrs:
	pushad
	pushfd

	mov ecx, dword [num_of_drones]
	init_ptrs_loop:
		mov eax, drone_func 								; saving drone_funcs address in eax
		mov edx, [drone_stack_ptrs] 		 				; calculating location of current drones pointer to function
		sub edx, 8
		shl ecx, 3 											; continue calculating
		add edx, ecx  										; continue calculating
		shr ecx, 3 											; restoring ecx original value
		mov dword [edx], eax 								; storing pointer to drone_func in stats array

		mov eax, ecx										; storing num of drones in edx for computation purposes
		shl eax, 14 										; multiplying num_of_drones by 16k
		add eax, [drone_stack]			 					; computation purposes
		mov edx, [drone_stack_ptrs]		 					; calculating location of current drones pointer to drones stack
		sub edx, 4
		shl ecx, 3 											; continue calculating
		add edx, ecx  										; continue calculating
		shr ecx, 3 											; restoring ecx original value
		mov dword [edx], eax 								; storing pointer to drone_stack in stats array
		loop init_ptrs_loop, ecx

	popfd
	popad
	ret

			; ecx - droneId
init_drone:
	pushad
	pushfd

	mov ebx, [drone_stack_ptrs]				; get pointer to drone pointers-struct 
	shl ecx, 3								; multiplying ecx(num_of_drones) by 8(size of each drones struct)
	add ebx, ecx							; adding offset to ebx
	shr ecx, 3								; restoring ecx original value
	sub ebx, 8 								; get to location of current drone in the struct
	mov eax, [ebx+CODEP]					; get initial EIP value – pointer to drone function
	mov dword [SPT], esp 					; save main ESP value
	mov esp, [ebx+SPP] 						; get initial ESP value – pointer to drone stack
	push eax  								; push initial “return” address(drone_func)
	pushfd   								; push flags of drone
	pushad   								; push all other registers of drone
	mov [ebx+SPP], esp   					; save new SPi value (after all the pushes)
	mov esp, dword [SPT]   					; restore ESP value 

	mov ebx, [drone_stats_arr] 				; getting pointer to drone_stats_arr
	mov edx ,ecx 							; computation purposes
	shl edx, 4 								; multiplying droneId by size of each drone stats array(16)
	add ebx, edx 							; adding offset to pointer
	sub ebx, 16

	call generate_loc	 					; generate starting x-position, returned in eax
	mov eax, [temp_num] 					; taking result of generate
	mov dword [ebx], eax					; store in stats array

	call generate_loc	 					; generate starting y-position, returned in eax
	mov eax, [temp_num] 					; taking result of generate
	mov dword [ebx+4], eax					; store in stats array

	call generate_angle 					; generate starting angle, returned in eax
	mov eax, [temp_num] 					; taking result of generate
	mov dword [ebx+8], eax					; store in stats array

	popfd
	popad 
	ret

init_target:
	mov dword [target_struct+CODEP], target_func 	; storing pointer to function
	mov dword [target_struct+SPP], target_stack 	; storing pointer to struct
	mov eax, target_func							; get initial EIP value – pointer to target function
	mov dword [SPT], esp 							; save main ESP value
	mov esp, [target_struct+SPP]					; get initial ESP value – pointer to target stack
	add esp, STKSIZE 								; pointing esp to the top of the stack
	push eax  										; push initial “return” address(target_func)
	pushfd   										; push flags of target
	pushad   										; push all other registers of target

	mov [target_struct+SPP], esp   					; save new SP value (after all the pushes)
	mov esp, dword [SPT]   							; restore ESP value 

	call generate_loc 								; generating x coordinate
	mov eax, [temp_num] 							; for computation purposes
	mov [target_loc_x], eax 						; storing in variable

	call generate_loc								; generating y coordinate
	mov eax, [temp_num]								; for computation purposes
	mov [target_loc_y], eax							; storing in variable
	ret

init_printer:
	mov dword [printer_struct+CODEP], printer_func
	mov dword [printer_struct+SPP], printer_stack
	mov eax, printer_func								; get initial EIP value – pointer to printer function
	mov dword [SPT], esp 								; save main ESP value
	mov esp, [printer_struct+SPP]						; get initial ESP value – pointer to printer stack
	add esp, STKSIZE 									; pointing esp to the top of the stack
	push eax  											; push initial “return” address(printer_func)
	pushfd   											; push flags of printer
	pushad   											; push all other registers of printer

	mov [printer_struct+SPP], esp   					; save new SP value (after all the pushes)
	mov esp, dword [SPT]   								; restore ESP value 
	ret

init_scheduler:
	mov dword [scheduler_struct+CODEP], scheduler_func
	mov dword [scheduler_struct+SPP], scheduler_stack
	mov eax, scheduler_func								; get initial EIP value – pointer to scheduler function
	mov dword [SPT], esp 								; save main ESP value
	mov esp, [scheduler_struct+SPP]						; get initial ESP value – pointer to scheduler 
	add esp, STKSIZE 									; pointing esp to the top of the stack
	push eax  											; push initial “return” address(scheduler_func)
	pushfd   											; push flags of scheduler
	pushad   											; push all other registers of scheduler

	mov [scheduler_struct+SPP], esp   					; save new SP value (after all the pushes)
	mov esp, dword [SPT]   								; restore ESP value 
	ret

		;; generators

generate_number:
	pushad
	mov ecx, 16								; num of iterations
	looper:
	 	cmp ecx, 0
	 	jng end_loop
		mov bx, [curr_random]				; initial number
		mov ax, 0							; initializing ax with 0
		mov dl, 0							; initializing dl with 0
		shr bx, 1							; to reach 16th bit
		adc byte [carry_flag_value], 0		; now carry_flag_value is lsb
		mov al, byte[carry_flag_value]
		mov byte [carry_flag_value], 0   	; zeroing cf-value
        shr bx, 2							; to reach 14th bit
        adc byte [carry_flag_value], 0		; now carry_flag_value is lsb
        mov dl, byte [carry_flag_value]
        mov byte [carry_flag_value], 0		; zeroing cf-value	
        xor al, dl							; xor between the needed bits
        shr bx, 1							; to reach 13th bit
        adc byte [carry_flag_value], 0		; now carry_flag_value is lsb
        mov dl, byte [carry_flag_value]
        mov byte [carry_flag_value], 0		; zeroing cf-value	
        xor al, dl							; xor between the needed bits
        shr bx, 2							; to reach 11th bit
        adc byte [carry_flag_value], 0		; now carry_flag_value is lsb
        mov dl, byte [carry_flag_value]
        mov byte [carry_flag_value], 0		; zeroing cf-value	
        xor al, dl							; xor between the needed bits

        mov bx, [curr_random] 				; for computation purposes
        shr bx, 1							; making room for new bit value
        shl ax, 15 							; new bit value moves from lsb to msb
        xor bx, ax							; new bit value becomes msb of shifted number
        mov word [curr_random], bx 			; putting new value in variable
        dec ecx								; decreasing counter
		jmp looper		 					; repeat 16 times
		
	end_loop:
		popad
		ret

generate_loc:
	pushad
	call generate_number
	call scale_loc
	popad
	ret

generate_angle:
	pushad
	call generate_number
	call scale_angle
	popad
	ret 

generate_delta_angle:
	pushad
	call generate_number
	call scale_delta_angle
	popad
	ret

generate_distance:
	pushad
	call generate_number
	call scale_distance
	popad
	ret

		;; scalors

scale_loc:
	fld dword [loc_max] 					; pushing 100 into x87
	fld dword [SHORT_MAX]					; pushing 65535(SHORT_MAX_VALUE) into x87
	fdivp st1, st0							; dividing 100/65535
	fild dword [curr_random] 				; pushing generated number into x87
	fmul 									; multiplying in order to scale the number
	fstp dword [temp_num] 					; saving result in temp
	ret

scale_angle:
	fld dword [angle_max] 					; pushing 360 into x87
	fld dword [SHORT_MAX]					; pushing 65535(SHORT_MAX_VALUE) into x87
	fdivp st1, st0							; dividing 360/65535
	fild dword [curr_random] 				; pushing generated number into x87
	fmulp st1, st0							; multiplying in order to scale the number
	fstp dword [temp_num] 					; saving result in temp
	ret

scale_delta_angle:
	fld dword [delta_angle_range] 			; pushing 120 into x87
	fld dword [SHORT_MAX]					; pushing 65535(SHORT_MAX_VALUE) into x87
	fdivp st1, st0							; dividing 120/65535
	fild dword [curr_random] 				; pushing generated number into x87
	fmulp st1, st0							; multiplying in order to scale the number
	fsub dword [minimum_delta_angle_val]	; reducing result by 60
	fstp dword [temp_num] 					; saving result in temp
	ret

scale_distance:
	fld dword [distance_max]				; pushing 50 into x87
	fld dword [SHORT_MAX]					; pushing 65535(SHORT_MAX_VALUE) into x87
	fdivp st1, st0							; dividing 50/65535
	fild dword [curr_random] 				; pushing generated number into x87
	fmulp st1, st0							; multiplying in order to scale the number
	fstp dword [temp_num]		 			; saving result in temp
	ret

resume: 					; save state of current co-routine
	pushfd
	pushad
	mov edx, [curr_struct]
	mov [edx+SPP], esp 		; save current esp

do_resume: 					; load esp for resumed co-routine
	mov esp, [ebx+SPP]
	mov [curr_struct], ebx
	popad 					; restore resumed co-routine state
	popfd
	ret 

arg_error:
	push args_error
	push format_string
	call printf
	add esp, 8
	ret

end_game:
	push dword [num_of_drones]
	call free
	add esp, 4

	push dword [drone_stack_ptrs]
	call free
	add esp, 4

	push dword [drone_stats_arr]
	call free
	add esp, 4

	mov esp, ebp 				; freeing func AF
	pop ebp 					; restore AF of main
	ret 						; return