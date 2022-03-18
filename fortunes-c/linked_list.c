#include <stdlib.h>
#include "linked_list.h"

void linked_list_append(linked_list_t ** head_p, void * data) {
    linked_list_t * new_head = malloc(sizeof(linked_list_t));
    new_head->next = *head_p;
    new_head->data = data;
    *head_p = new_head;
}

void * linked_list_extract(linked_list_t ** head_p) {
    void * data = (*head_p)->data;
    linked_list_t * next = (*head_p)->next;
    free(*head_p);
    *head_p = next;
    return data;
}

void linked_list_flush(linked_list_t ** head_p) {
    linked_list_t * head = *head_p;
    while (head != NULL) {
        linked_list_t * n = head->next;
        free(head);
        head = n;
    }
}

bool linked_list_empty(linked_list_t * head) {
    return head==NULL;
}

int linked_list_length(linked_list_t * head) {
    int l = 0;
    linked_list_t * p = head;
    while (p!=NULL) {
        l ++;
        p = p->next;
    }
    return l;
}

void * linked_list_walk(linked_list_t ** head_p) {
    void * data = (*head_p)->data;
    *head_p = (*head_p)->next;
    return data;
}

bool linked_list_remove(linked_list_t ** head_p, void * data) {
    linked_list_t * head = *head_p;
    if (!head)
        return false;
    if (head->data == data) { // первый элемент в любом случае обрабатываем отдельно, т.к. у него нет предыдущего
        // TODO код тут как в linked_list_extract
        linked_list_t * next = head->next;
        free(*head_p);
        *head_p = next;
        return true;
    }
    // TODO рекурсивная форма функции проста, но возможно лучше было бы всё-таки развернуть рекурсию и обходить список явно
    return linked_list_remove(&(head->next), data);
}
