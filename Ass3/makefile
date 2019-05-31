
all: ass3

ass3 : ass3.o drone.o target.o printer.o scheduler.o
	gcc -m32 -g -Wall ass3.o drone.o target.o printer.o scheduler.o -o ass3

ass3.o : ass3.s
	nasm -g -f elf -w+all ass3.s -o ass3.o 

drone.o: drone.s
	nasm -g -f elf -w+all drone.s -o drone.o

target.o: target.s
	nasm -g -f elf -w+all target.s -o target.o

printer.o: printer.s
	nasm -g -f elf -w+all printer.s -o printer.o

scheduler.o: scheduler.s
	nasm -g -f elf -w+all scheduler.s -o scheduler.o

.PHONY : clean
clean : 
	rm -f *.o ass3