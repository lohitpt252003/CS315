
CC = g++
CFLAGS = -Wall -O2 -std=c++11

all:
	$(CC) $(CFLAGS) external_quicksort.cpp -o external_quicksort

clean:
	rm -f external_quicksort external_quicksort.exe

run:
	./external_quicksort $(FILE) $(N) $(K) $(B) $(M)

test:
	python generate_input.py 10000 input.txt
	./external_quicksort input.txt 10000 4 1024 10
