#include <stdlib.h> 
#include <stdio.h>
#include <unistd.h>

int main(int argc, char *argv[]){

	if(argc != 3){
		printf( "usage: spleepwaste TIME MEM");
		exit(1);
	}
	char *v = (char *) malloc( atol(argv[2])*1024*1024 * sizeof(char) );

	unsigned i=0;
	for( i=0; i<atol(argv[2])*1024*1024; i++ ){
// 		if (i % 1000000 == 0)
// 			printf("i %d\n", i/1000000);
		v[i] = 1;
	}
       
 	sleep(atoi(argv[1]));
	free(v);

	printf("slept for %d s and %d MB\n", atoi(argv[2]), i );
	exit(0);
}
