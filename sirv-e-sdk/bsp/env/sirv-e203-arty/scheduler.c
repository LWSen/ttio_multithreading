#include<scheduler.h>
#include <stdio.h>
#include <stdlib.h>
#include "platform.h"
#include <string.h>
#include "plic/plic_driver.h"
#include "encoding.h"
#include <unistd.h>
#include "stdatomic.h"
void enqueue(task_queue *queue, function_ptr task){
	task_node *new_task = (task_node*)malloc(sizeof(task_node));
	new_task->task = task;
	new_task->next_task = NULL;
	queue->tail->next_task = new_task;
	queue->tail = new_task;
	//printf("enqueue:%x\n", (int)(queue->tail->task));
}

function_ptr dequeue(task_queue *queue){
	task_node *ret_task = queue->head->next_task;
	queue->head->next_task = ret_task->next_task;
	if(ret_task==queue->tail) queue->tail = queue->head;
	return ret_task->task;
}

int is_empty(task_queue *queue){
	if(queue->head==queue->tail) return 1;
	return 0;
}

void init_queue(){
	int i;
	for(i=0;i<2;i++){
		q[i] = (task_queue*)malloc(sizeof(task_queue));
		q[i]->head = (task_node*)malloc(sizeof(task_node));
		q[i]->head->task = NULL;
		q[i]->head->next_task = NULL;
		q[i]->tail = q[i]->head;
	}
}

void scheduler(){
	int hartid = read_csr(mhartid);
	while(1){
		if(!is_empty(q[hartid])){
			function_ptr task = dequeue(q[hartid]);
			task();
		}
		//else printf("No task\n");
	}
}

