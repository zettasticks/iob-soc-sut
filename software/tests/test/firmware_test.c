#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include "iob-uart.h"
#include "system.h"

#define Address_write 0x9004 //address where the writting starts
#define N 1000

volatile int * vect;

void main()
{ 
  int counter, reg = 0 ;
  unsigned char ledvar = 0;
  unsigned char Numb = 0;

  uart_init(UART_BASE,UART_CLK_FREQ/UART_BAUD_RATE);
   
  //uart_write_wait();
  uart_puts("\n... Initializing program in main memory:\n");
  vect = (volatile int*) AUXMEM_BASE;

  uart_printf("Test. Is this working?\n");

  
  for (counter = 0; counter < N; counter ++){
    vect[counter] = counter;
  }
  //uart_write_wait();
  uart_puts("Wrote all numbers, the last printed: \n");
  //uart_write_wait();
  uart_printf("%x\n", vect[N-1]);
  //uart_write_wait();
  uart_puts("Verification of said numbers:\n");

  for (counter = 0; counter < N; counter ++){
    if (vect[counter] != counter){
      //uart_write_wait();
      uart_printf("fail:%x\n", counter);
    }
  }
  //uart_write_wait();
  uart_puts("End of program\n");

  while(1);

}