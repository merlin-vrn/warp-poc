CC := gcc -c --std=c99 -ggdb -DTCL_OUTPUT
#-DTCL_OUTPUT
#-DDEBUG_OUTPUT
#-DMALLOC_OUTPUT
LIBS := -lm
TCLINC := /usr/include/tcl8.6
TCLLIB := /usr/lib/x86_64-linux-gnu

.PHONY: all clean

all: run run.o priority_queue.o fortunes.o linked_list.o libvoronoi.so

clean:
	rm -rf run *.o *.so

priority_queue.o: priority_queue.h priority_queue-ascending.c
	$(CC) -o priority_queue.o priority_queue-ascending.c

linked_list.o: linked_list.h linked_list.c
	$(CC) -o linked_list.o linked_list.c

fortunes.o: fortunes.h fortunes.c
	$(CC) -o fortunes.o fortunes.c

run.o: run.c
	$(CC) -o run.o run.c

run: priority_queue.o fortunes.o run.o linked_list.o
	gcc -o run run.o fortunes.o priority_queue.o linked_list.o $(LIBS)

voronoi.o: voronoi.c
	$(CC) -DUSE_TCL_STUBS -I$(TCLINC) voronoi.c

libvoronoi.so: voronoi.o priority_queue.o fortunes.o linked_list.o
	gcc -shared -o libvoronoi.so voronoi.o fortunes.o priority_queue.o linked_list.o -L$(TCLLIB) -ltclstub8.6 $(LIBS)
