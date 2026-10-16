#include <stdio.h>

int main(){
  int *r = 0xC7DF;
  char a = 'c';
  int b = 33;

  for (int i=0; i<2; i++) {
    if (i==0){
      a = 'b';
    }
    else{
      b = b<<1;
      b = b&0xF;
    }

  }

  // printf("Result is %d and string is %c\n", b, a);
}
