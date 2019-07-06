#ifndef _SCHEDULER_H_
#define _SCHEDULER_H_
typedef void (*function_ptr)();
typedef struct{
	function_ptr task;
	struct task_node *next_task;
}task_node;

typedef struct{
	task_node *head;
	task_node *tail;
}task_queue;
task_queue *q[2];

void enqueue(task_queue *queue, function_ptr task);
function_ptr dequeue(task_queue *queue);
int is_empty(task_queue *queue);
void init_queue();
void scheduler();
#endif
