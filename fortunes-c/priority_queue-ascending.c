#include "priority_queue.h"

#include <stdlib.h>
#include <stdio.h>

void pq_init(heapqueue_t * queue) {
    queue->a = malloc(HEAPQUEUE_ALLOCATION_STEP * sizeof(heapqueue_item_t));
    queue->s = HEAPQUEUE_ALLOCATION_STEP;
    queue->n = 0;
}

void pq_destroy(heapqueue_t * queue) {
    free(queue->a);
    queue->a = NULL;
    queue->n = 0;
    queue->s = 0;
}

void pq_enqueue(heapqueue_t * queue, const HEAPQUEUE_PRIO_TYPE prio, HEAPQUEUE_DATA_TYPE data) {
    if (queue->n == queue->s-1) {
        // enlarge the array
        heapqueue_item_t * new_a = realloc(queue->a, (queue->s+HEAPQUEUE_ALLOCATION_STEP) * sizeof(heapqueue_item_t));
        if (new_a == NULL) {
            printf("can't realloc\n");
            return;
        }
        queue->a = new_a;
        queue->s += HEAPQUEUE_ALLOCATION_STEP;
    }

    // first insert at the last position of the array
    queue->a[queue->n].p = prio;
    queue->a[queue->n].d = data;
    queue->n += 1;

    // move up until the heap property satisfies
    HEAPQUEUE_COUNT_TYPE i = queue->n - 1; // last element
    HEAPQUEUE_COUNT_TYPE parent = (i-1)/2;
    while (i != 0 && queue->a[parent].p > queue->a[i].p) {
        // swap
        heapqueue_item_t temp = queue->a[parent];
        queue->a[parent] = queue->a[i];
        queue->a[i] = temp;
        // move to the parent
        i = parent;
        parent = (i-1)/2;
    }
}

// TODO: избавиться от рекурсии
void max_heapify(heapqueue_t * queue, const HEAPQUEUE_COUNT_TYPE i) {
    HEAPQUEUE_COUNT_TYPE left = 2 * i + 1;
    HEAPQUEUE_COUNT_TYPE right = 2 * i + 2;

    // find the smallest among 3 nodes
    HEAPQUEUE_COUNT_TYPE smallest = i;
    if (left <= queue->n && queue->a[left].p < queue->a[smallest].p) smallest = left;
    if (right <= queue->n && queue->a[right].p < queue->a[smallest].p) smallest = right;

    // swap the smallest node with the current node 
    // and repeat this process until the current node is larger than the right and the left node
    if (smallest != i) {
        heapqueue_item_t temp = queue->a[i];
        queue->a[i] = queue->a[smallest];
        queue->a[smallest] = temp;
        max_heapify(queue, smallest);
    }
}

HEAPQUEUE_DATA_TYPE pq_dequeue(heapqueue_t * queue) {
    HEAPQUEUE_DATA_TYPE item = queue->a[0].d;

    // replace the first item with the last item
    queue->n -= 1;
    queue->a[0] = queue->a[queue->n];

    // maintain the heap property by heapifying the first item
    max_heapify(queue, 0);
    return item;
}

bool pq_empty(const heapqueue_t * queue) {
    return queue->n == 0;
}

HEAPQUEUE_PRIO_TYPE pq_prio(const heapqueue_t * queue) {
    return queue->a[0].p;
}
