#include "bsp.h"
#include "clint.h"
#include "iob-uart16550.h"
#include "iob_soc_sut_conf.h"
#include "iob_soc_sut_system.h"
#include "iob_soc_sut_periphs.h"
#include "printf.h"
#include "iob-eth.h"
#include <string.h>

#if __has_include("iob_soc_tester_conf.h")
#define USE_TESTER
#endif

#define PROGNAME "IOb-Bootloader"

#define DC1 17 // Device Control 1 (used to indicate end of bootloader)
#define EXT_MEM 0x80000000


// Ethernet utility functions
//NOTE: These functions are not compatible with malloc() and free().
//      These are specifically made for use with the current iob-eth.c drivers.
//      (These assume that there is only one block allocated at a time)
static void* mem_alloc(size_t size){
  return (void *)(EXT_MEM | (1<<IOB_SOC_SUT_MEM_ADDR_W)) - size;
}
static void mem_free(void* ptr){}

void clear_cache(){
  // Delay to ensure all data is written to memory
  for ( unsigned int i = 0; i < 10; i++)asm volatile("nop");
  // Flush VexRiscv CPU internal cache
  asm volatile(".word 0x500F" ::: "memory");
}


// Send signal by uart to receive file by ethernet
uint32_t uart_recvfile_ethernet(char *file_name) {
  uart16550_puts(UART_PROGNAME);
  uart16550_puts (": requesting to receive file by ethernet\n");

  //send file receive by ethernet request
  uart16550_putc (0x13);

  //send file name (including end of string)
  uart16550_puts(file_name); uart16550_putc(0);

  // receive file size
  uint32_t file_size = uart16550_getc();
  file_size |= ((uint32_t)uart16550_getc()) << 8;
  file_size |= ((uint32_t)uart16550_getc()) << 16;
  file_size |= ((uint32_t)uart16550_getc()) << 24;

  // send ACK before receiving file
  uart16550_putc(ACK);

  return file_size;
}

int main() {
  int i;
  int run_linux = 0;
  int file_size;
  char *prog_start_addr;

  // init uart
  uart16550_init(UART0_BASE, FREQ / (16 * BAUD));

  // connect with console
  do {
    if (uart16550_txready())
      // Send 0xff (to allow start bit synchronization) followed by ENQ
      uart16550_puts((char [3]){0xff, ENQ, 0x00});
  } while (!uart16550_rxready());

#ifdef USE_TESTER
  // Receive a special ACK message from tester to prevent Linux from acking by mistake
  char tester_ack[] = "Tester ACK";
  for ( i = 0; i < 10; ) {
    if (uart16550_getc() == tester_ack[i])
      i++;
    else
      i = 0;
  }
#endif //USE_TESTER

  // welcome message
  uart16550_puts(PROGNAME);
  uart16550_puts(": connected!\n");

  uart16550_puts(PROGNAME);
  uart16550_puts(": DDR in use and program runs from DDR\n");

  // address to copy firmware to
  prog_start_addr = (char *)(EXT_MEM);

#ifndef USE_TESTER
  while (uart16550_getc() != ACK) {
    uart16550_puts(PROGNAME);
    uart16550_puts(": Waiting for Console ACK.\n");
  }
#endif //USE_TESTER

#ifndef IOB_SOC_SUT_INIT_MEM
  // Init ethernet and printf (for ethernet)
  printf_init(&uart16550_putc);
  eth_init(ETH0_BASE, &clear_cache);
  // Use custom memory alloc/free functions to ensure it allocates in external memory
  eth_init_mem_alloc(&mem_alloc, &mem_free);
  // Wait for PHY reset to finish
  eth_wait_phy_rst();

  file_size = uart16550_recvfile("../iob_soc_sut_mem.config", prog_start_addr);
  // compute_mem_load_txt
  int state = 0;
  int file_name_count = 0;
  int file_count = 0;
  char file_name_array[4][50];
  long int file_address_array[4];
  char hexChar = 0;
  int hexDecimal = 0;
  for (i = 0; i < file_size; i++) {
    hexChar = *(prog_start_addr + i);
    //uart16550_puts(&hexChar); /* Used for debugging. */
    if (state == 0) {
      if (hexChar == ' ') {
        file_name_array[file_count][file_name_count] = '\0';
        file_name_count = 0;
        file_address_array[file_count] = 0;
        file_count = file_count + 1;
        state = 1;
      } else {
        file_name_array[file_count][file_name_count] = hexChar;
        file_name_count = file_name_count + 1;
      }
    } else if (state == 1) {
      if (hexChar == '\n') {
        state = 0;
      } else {
        if ('0' <= hexChar && hexChar <= '9') {
          hexDecimal = hexChar - '0';
        } else if ('a' <= hexChar && hexChar <= 'f') {
          hexDecimal = 10 + hexChar - 'a';
        } else if ('A' <= hexChar && hexChar <= 'F') {
          hexDecimal = 10 + hexChar - 'A';
        } else {
          uart16550_puts(PROGNAME);
          uart16550_puts(": invalid hexadecimal character.\n");
        }
        file_address_array[file_count-1] =
            file_address_array[file_count-1] * 16 + hexDecimal;
      }
    }
  }

  for (i = 0; i < file_count; i++) {
    prog_start_addr = (char *)(EXT_MEM + file_address_array[i]);
    // Receive data from console via Ethernet (only on fpga without tester)
#if !defined(SIMULATION) && !defined(USE_TESTER)
    file_size = uart_recvfile_ethernet(file_name_array[i]);
    eth_rcv_file(prog_start_addr,file_size);
#else
    file_size = uart16550_recvfile(file_name_array[i], prog_start_addr);
#endif
  }

  // Check if running Linux
  for (i = 0; i < file_count; i++) {
    if (!strcmp(file_name_array[i], "rootfs.cpio.gz")){
#ifdef SIMULATION
      // Running Linux: setup required dependencies
      uart16550_sendfile("test.log", 12, "Test passed!");
      uart16550_putc((char)DC1);
#endif
      run_linux=1;
      break;
    }
  }
#else // INIT_MEM = 1
#ifdef IOB_SOC_SUT_RUN_LINUX
    // Running Linux: setup required dependencies
    uart16550_sendfile("test.log", 12, "Test passed!");
    uart16550_putc((char)DC1);
#endif
#endif

  // Clear CPU registers, to not pass arguments to the next
  asm volatile("li a0,0");
  asm volatile("li a1,0");
  asm volatile("li a2,0");
  asm volatile("li a3,0");
  asm volatile("li a4,0");
  asm volatile("li a5,0");
  asm volatile("li a6,0");
  asm volatile("li a7,0");

  // run firmware
  uart16550_puts(PROGNAME);
  uart16550_puts(": Restart CPU to run user program...\n");
  uart16550_txwait();

#ifndef SIMULATION
  // Terminate console if running Linux on FPGA
  if (run_linux)
    uart16550_finish();
#endif
}
