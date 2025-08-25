//ERROR FREE - This test case includes array declarations, and conditional statements
#include<stdio.h>

char h1(int a[10][45],int i);

int main()
{
	int A[5] = {1,2,3,4,5};
	char B[10] = "Hello";
	int x = 45;
	int d[50][30];
	if(B[0] == 'H'){
		if(A[0] == '1')
			printf("Hello 1");
		else
			printf("Hello 2");
			h1(B,1);
	}
	
	else
		printf("Not Hello");
}
	