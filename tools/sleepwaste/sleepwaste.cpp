#include <iostream>
#include <stdlib.h> 
#include <unistd.h>
#include <vector>
using namespace std;

int main(int argc, char *argv[]){

	if(argc != 3){
		cerr << "usage: spleepwaste TIME MEM"<< endl;
		exit(1);
	}
	unsigned mem=atoi(argv[2])*1024*1024,
			 time = atoi(argv[1]);

	vector<char> v = vector<char>(mem);
 	sleep(time);

	cout << "slept for "<<time<<" s and wasted "<<argv[2]<<" MB"<<endl;

	exit(0);
}
