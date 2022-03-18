
#if defined(DO_TEST_QUEUE)
void test_queue(void) {
    heapqueue_t queue;
    pq_init(&queue);
    int a[] = {1, 2, 3, 4, 5, 6, 7};
    long double p[] = {0.21, 5.42, 11.3, -2.1, 42.1, 1000, 0.11};
    for (int i = 0; i < 5; i++) {
        printf("adding: %Lg %i\n", p[i], a[i]);
        pq_enqueue(&queue, p[i], &a[i]);
    }
    for (int i = 0; i < 2; i++)
        printf("removing: %d \n", * (int *) pq_dequeue(&queue));
    for (int i = 5; i < 7; i++) {
        printf("adding: %Lg %i\n", p[i], a[i]);
        pq_enqueue(&queue, p[i], &a[i]);
    }
    while (!pq_empty(&queue))
        printf("removing: %d \n", * (int *) pq_dequeue(&queue));
    pq_destroy(&queue);
    return;
}
#endif
