#include <stdio.h>
#include <stdlib.h>
#include "platform.h"
#include <string.h>
#include "plic/plic_driver.h"
#include "encoding.h"
#include <unistd.h>
#include "stdatomic.h"
#include "scheduler.h"
#define one_ms 33
//plic_instance_t g_plic;
volatile uint64_t * mtime = (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIME);

void delay_ms(int time){
	uint64_t delay_time = *mtime + time * one_ms;
	while(*mtime < delay_time);
}
	
  	
/*Entry Point for Machine Timer Interrupt Handler*/

void handle_m_time_interrupt(){

  clear_csr(mie, MIP_MTIP);

  // Reset the timer for 3s in the future.
  // This also clears the existing timer interrupt.

  volatile uint64_t * mtime       = (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIME);
  volatile uint64_t * mtimecmp    = (uint64_t*) (CLINT_CTRL_ADDR + CLINT_MTIMECMP);
  uint64_t now = *mtime;
  uint64_t then = now + 100 * one_ms;
  *mtimecmp = then;
	printf("handle interrupt\n");
  
  // Re-enable the timer interrupt.
  set_csr(mie, MIP_MTIP);

}
	
void task1(){
	int i;
	for(i=0;i<3;i++){
		delay_ms(25);
		printf("task1\n");
		delay_ms(25);
	}
	
}

void task2(){
	int i;
	for(i=0;i<3;i++){
		delay_ms(25);
		printf("task2\n");
		delay_ms(25);
	}
	
}

void task0(){

	int fib[6];
	int i;
		
	fib[0]=1;
	fib[1]=1;
	for(i=0;i<6;i++){
		if(i>1) fib[i] = fib[i-2]+fib[i-1];
		printf("fib[%d]=%d\n",i,fib[i]);
		delay_ms(50);
		
	}

}

/*
initialize task queues: q[0] and q[1]
task0 runs on q[0]
task1 and task2 run on q[1]
*/
void enroll(){
	enqueue(q[0],task0);
    	enqueue(q[1],task1);
    	enqueue(q[1],task2);
	
}


