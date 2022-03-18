#if !defined(_LINKED_LIST_H)
#define _LINKED_LIST_H

#include <stdbool.h>

typedef struct linked_list_s linked_list_t;
struct linked_list_s {
    void * data;
    linked_list_t * next;
};

// Добавить объект в список: void * data; linked_list_t * t = NULL; linked_list_append(&t, data);
void linked_list_append(linked_list_t **, void *);

// Удалить последний элемент из списка и вернуть его: while (!linked_list_empty) { void * data = linked_list_extract(&t); }; можно кастовать в нужный тип прямо здесь
void * linked_list_extract(linked_list_t **);

// Очистить список
void linked_list_flush(linked_list_t **);

// Проверяет, пуст ли список
bool linked_list_empty(linked_list_t *);

// Вычисляет длину списка
int linked_list_length(linked_list_t *);

// Проходит к следующему элементу списка, но ничего не удаляет
void * linked_list_walk(linked_list_t **);

// Проходит по списку и удаляет первый найденный элемент с указанным значением. Возвращает true если удаление произошло, false если такого элемента не было.
bool linked_list_remove(linked_list_t **, void *);

#endif
