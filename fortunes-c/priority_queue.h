#if !defined(_PRIORITY_QUIUE_H)
#define _PRIORITY_QUIUE_H

#include <stdbool.h>

#define HEAPQUEUE_DATA_TYPE void *
#define HEAPQUEUE_PRIO_TYPE long double
#define HEAPQUEUE_ALLOCATION_STEP 16
#define HEAPQUEUE_COUNT_TYPE unsigned long long

typedef struct {
    HEAPQUEUE_DATA_TYPE d;
    HEAPQUEUE_PRIO_TYPE p;
} heapqueue_item_t;

typedef struct {
    heapqueue_item_t *a;
    HEAPQUEUE_COUNT_TYPE n; // количество элементов в очереди
    HEAPQUEUE_COUNT_TYPE s; // выделено памяти для этого количества элементов массива
} heapqueue_t;

// инициализация очереди
void pq_init(heapqueue_t *);

// очистка памяти
void pq_destroy(heapqueue_t *);

// вставляет элемент в надлежащую позицию
void pq_enqueue(heapqueue_t *, const HEAPQUEUE_PRIO_TYPE, HEAPQUEUE_DATA_TYPE);
// TODO: на самом деле тут const HEAPQUEUE_DATA_TYPE data, но возникает предупреждение
// warning: assignment discards 'const' qualifier from pointer target type [-Wdiscarded-qualifiers]


// удаляет первый элемент очереди
HEAPQUEUE_DATA_TYPE pq_dequeue(heapqueue_t *);

// сообщает, пуста ли очередь
bool pq_empty(const heapqueue_t *);

// сообщает приоритет первого элемента
HEAPQUEUE_PRIO_TYPE pq_prio(const heapqueue_t *);

#endif
