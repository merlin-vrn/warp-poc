#include <stdlib.h>
#include <stdbool.h>
#include <math.h>

#include <stdio.h>

#include "fortunes.h"
#include "priority_queue.h"

// цветной вывод
#if defined(DEBUG_OUTPUT)
#include "ansi.h"
#define CL_NEW(n) ANSI_FG(ANSI_BRIGHT(ANSI_GREEN)) n ANSI_FG_DEFAULT
#define CL_MODIFIED(n) ANSI_FG(ANSI_BRIGHT(ANSI_MAGENTA)) n ANSI_FG_DEFAULT
#define CL_OLD(n) ANSI_FG(ANSI_BRIGHT(ANSI_BLUE)) n ANSI_FG_DEFAULT
#define CL_QUESTION(n) ANSI_FG(ANSI_BRIGHT(ANSI_YELLOW)) n ANSI_FG_DEFAULT
#define CL_DELETED(n) ANSI_FG(ANSI_BRIGHT(ANSI_RED)) n ANSI_FG_DEFAULT
#define ANSI_IMPORTANT ANSI_BG(ANSI_RED) ANSI_FG(ANSI_BRIGHT(ANSI_WHITE))
#define ANSI_SECTION ANSI_BG(ANSI_GREEN) ANSI_FG(ANSI_BRIGHT(ANSI_WHITE))
#define CL_FUNC_ENTRY(n) ANSI_FG(ANSI_BRIGHT(ANSI_BLACK)) n ANSI_RESET
#endif

#if defined MALLOC_OUTPUT
#define DEBUG_MALLOC(a,b,c) printf("\n%p  malloc %2lu %s\n", (a), (b), (c));
#define DEBUG_REALLOC(a,b,c) printf("\n%p realloc %2lu %s\n", (a), (b), (c));
#define DEBUG_FREE(a,b,c) printf("\n%p    free %2lu %s\n", (a), (b), (c));
#else
#define DEBUG_MALLOC(a,b,c)
#define DEBUG_REALLOC(a,b,c)
#define DEBUG_FREE(a,b,c)
#endif

typedef struct beachline_object_s beachline_object_t;
typedef struct event_s event_t;

typedef enum {
    BEACHLINE_BREAKPOINT,
    BEACHLINE_ARC
} beachline_object_type_t;

typedef enum {
    TREE_PATH_LEFT,
    TREE_PATH_RIGHT
} tree_path_t;

typedef enum {
    EVENT_TYPE_SITE,
    EVENT_TYPE_CIRCLE
} event_type_t;

struct beachline_object_s {
#if defined(DEBUG_OUTPUT)
    char id[MAX_ID_LENGTH];
#endif
    beachline_object_type_t type;
    beachline_object_t * parent;
    tree_path_t path;
    union {
        struct {
            voronoi_site_t * left_site, * right_site;
            beachline_object_t * left_descendant, * right_descendant;
            voronoi_edge_t * edge;
        };
        struct {
            voronoi_site_t * site;
            beachline_object_t * left_breakpoint, * right_breakpoint;
            beachline_object_t * left_arc, * right_arc;
            event_t * circle;
        };
    };
};

struct event_s {
    event_type_t type;
    union {
        struct {
            long double x;
            long double y;
            long double r;
            beachline_object_t * arc;
            bool invalid;
        };
        struct {
            voronoi_site_t * site;
        };
    };
};


typedef struct {
    beachline_object_t * tree;
    voronoi_diagram_t * diagram;
    heapqueue_t queue;
    linked_list_t * lost_edges; // сюда попадут полурёбра, уходящие в бесконечность
    linked_list_t * edges; // копим полурёбра здесь TODO: сразу в diagram->edges
    linked_list_t * vertices; // и вершины тоже, и такое же TODO
} fortunes_structure_t;

void handle_site_event(fortunes_structure_t *, event_t *);
void handle_circle_event(fortunes_structure_t *, event_t *);

beachline_object_t * create_arc(voronoi_site_t *, beachline_object_t *, const tree_path_t);
beachline_object_t * find_arc_above(const fortunes_structure_t *, const long double, const long double);
void destroy_arc(beachline_object_t *);

void check_add_circle(fortunes_structure_t *, beachline_object_t */*, const long double*/);

beachline_object_t * create_breakpoint(voronoi_site_t *, voronoi_site_t *);
void destroy_breakpoint_only(beachline_object_t *);
void destroy_breakpoint_recursive(fortunes_structure_t *, beachline_object_t *);

voronoi_edge_t * create_edge_pair(fortunes_structure_t *, voronoi_site_t *, voronoi_site_t *, voronoi_vertex_t *);
voronoi_vertex_t * create_vertex(fortunes_structure_t *, const long double, const long double, const long double);

void add_dummy_site(voronoi_site_t *, const point_t points[], const int, fortunes_structure_t *);
void delete_dummy_site();

//===================================================================================================================================================================

void add_dummy_site(voronoi_site_t * s, const point_t points[], const int points_count, fortunes_structure_t * fortunes) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("add_dummy_site(...)") "\n");
#endif
    event_t * evt = malloc(sizeof(event_t));
    DEBUG_MALLOC(evt, sizeof(event_t), "event_t");
    evt->type = EVENT_TYPE_SITE;
    s->point.x = points[0].x; // значение координаты x не очень существенно
    // TODO: убрать колдунство с залезанием в имплементацию очереди; объявить функцию в priority_queue.h и вызывать её отсюда
    // первый элемент минимальный, а последний наверняка больше; 1 это "запас", вдруг там такое же число или вообще все элементы одинаковые.
    s->point.y = 2*pq_prio(&fortunes->queue)-fortunes->queue.a[fortunes->queue.n-1].p-1;
    s->vertices = NULL;
    s->edges = NULL;
#if defined(TCL_OUTPUT)
        snprintf(s->id, MAX_ID_LENGTH, "s%d", points_count);
#endif
    evt->site = s;
    pq_enqueue(&fortunes->queue, s->point.y, evt);
#if defined(DEBUG_OUTPUT)
    printf("Добавлен \"фиктивный\" сайт " CL_QUESTION("%s") " (%Lg, %Lg)\n", s->id, s->point.x, s->point.y);
#endif
}

void delete_dummy_site(voronoi_site_t * s, fortunes_structure_t * fortunes, const int points_count) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("delete_dummy_site(%s, ...)") "\n", s->id);
    printf(ANSI_SECTION "Удаление \"фиктивного\" сайта " CL_QUESTION("%s") ANSI_SECTION " (%Lg, %Lg)" ANSI_RESET "\n", s->id, s->point.x, s->point.y);
#endif
    // Перебираем все вершины, связанные с удаляемым сайтом. Все эти вершины будут удалены.
    // Ссылки на них нужно удалить из сайтов, которые в них смыкались (кроме удаляемого сайта s), и из полурёбер, которые в них начинались и заканчивались.
    while (!linked_list_empty(s->vertices)) {
        voronoi_vertex_t * vertex_remove = (voronoi_vertex_t *) linked_list_extract(&(s->vertices));
#if defined(DEBUG_OUTPUT)
        printf("Вершина " CL_DELETED("%s") " (%Lg, %Lg; %Lg): смыкаются", vertex_remove->id, vertex_remove->point.x, vertex_remove->point.y, vertex_remove->distance);
#endif
        // сайты, которые смыкаются в этой вершине
        while (!linked_list_empty(vertex_remove->sites)) {
            voronoi_site_t * site_to_clean = (voronoi_site_t *) linked_list_extract(&(vertex_remove->sites));
            // кроме удаляемого сайта
            if (site_to_clean == s)
                continue;
#if defined(DEBUG_OUTPUT)
            printf(" " CL_MODIFIED("%s"), site_to_clean->id);
#endif
            if (!linked_list_remove(&(site_to_clean->vertices), vertex_remove)) {
#if defined(DEBUG_OUTPUT)
                printf(ANSI_IMPORTANT "(не было ссылки)" ANSI_RESET);
#endif
            }
        }
#if defined(DEBUG_OUTPUT)
        printf(", входят");
#endif
        // полурёбра, которые входят в эту вершину
        while (!linked_list_empty(vertex_remove->edges_in)) {
            voronoi_edge_t * edge_to_clean = (voronoi_edge_t *) linked_list_extract(&(vertex_remove->edges_in));
#if defined(DEBUG_OUTPUT)
            printf(" " CL_MODIFIED("%s"), edge_to_clean->id);
            if (edge_to_clean->target != vertex_remove) {
                if (edge_to_clean->target)
                    printf(ANSI_IMPORTANT "(некорректная ссылка: %s)" ANSI_RESET, edge_to_clean->target->id);
                else
                    printf(ANSI_IMPORTANT "(не было ссылки)" ANSI_RESET);
            }
#endif
            edge_to_clean->target = NULL;
            // это полуребро стало уходящим в бесконечность — добавляем к соответствующему списку
            linked_list_append(&fortunes->lost_edges, edge_to_clean);
        }
#if defined(DEBUG_OUTPUT)
        printf(", выходят");
#endif
        // полурёбра, которые выходят из этой вершины
        while (!linked_list_empty(vertex_remove->edges_out)) {
            voronoi_edge_t * edge_to_clean = (voronoi_edge_t *) linked_list_extract(&(vertex_remove->edges_out));
#if defined(DEBUG_OUTPUT)
            printf(" " CL_MODIFIED("%s"), edge_to_clean->id);
            if (edge_to_clean->origin != vertex_remove) {
                if (edge_to_clean->origin)
                    printf(ANSI_IMPORTANT "(некорректная ссылка: %s)" ANSI_RESET, edge_to_clean->origin->id);
                else
                    printf(ANSI_IMPORTANT "(не было ссылки)" ANSI_RESET);
            }
#endif
            edge_to_clean->origin = NULL;
        }
#if defined(DEBUG_OUTPUT)
        printf("\n");
#endif
        // удаляем её из общего списка вершин
        linked_list_remove(&fortunes->vertices, vertex_remove);
        
        // и из памяти
        DEBUG_FREE(vertex_remove, sizeof(voronoi_vertex_t), "voronoi_vertex_t");
        free(vertex_remove);
    }

    // Перебираем все полурёбра, связанные с удаляемым сайтом. Эти полурёбра, а также их "двойники", будут удалены.
    // Вычищать ссылки из полурёбер данного сайта нет смысла.
    // Но нужно удалить ссылку на двойник из соседнего сайта, а также удалить ссылки из его последующего и предыдущего ребра.
    while (!linked_list_empty(s->edges)) {
        voronoi_edge_t * edge_remove = (voronoi_edge_t *) linked_list_extract(&(s->edges));
        voronoi_edge_t * sibling_remove = edge_remove->sibling;
#if defined(DEBUG_OUTPUT)
        printf("Полуребро " CL_DELETED("%s") ": ↑↓ " CL_MODIFIED("%s") " → " CL_DELETED("%s") "(" CL_MODIFIED("%s") ") → " CL_MODIFIED("%s") "\n",
               edge_remove->id, (sibling_remove->previous)?sibling_remove->previous->id:"...",
               sibling_remove->id, sibling_remove->site->id, (sibling_remove->next)?sibling_remove->next->id:"...");
#endif
        linked_list_remove(&sibling_remove->site->edges, sibling_remove);
        if (sibling_remove->previous)
            sibling_remove->previous->next = NULL;
        if (sibling_remove->next)
            sibling_remove->next->previous = NULL;
      
        // удаляем оба из списка полурёбер
        linked_list_remove(&fortunes->edges, edge_remove);
        linked_list_remove(&fortunes->edges, sibling_remove);
      
        // из списка бесконечных полурёбер
        linked_list_remove(&fortunes->lost_edges, edge_remove);
        linked_list_remove(&fortunes->lost_edges, sibling_remove);
      
        // и из памяти
        DEBUG_FREE(edge_remove, sizeof(voronoi_edge_t), "voronoi_edge_t");
        DEBUG_FREE(sibling_remove, sizeof(voronoi_edge_t), "voronoi_edge_t");
        free(edge_remove);
        free(sibling_remove);
    }
    
    // Фиктивный сайт был последним, так что просто перевыделяем массив без последнего элемента
    fortunes->diagram->sites = realloc(fortunes->diagram->sites, points_count * sizeof(voronoi_site_t));
    DEBUG_REALLOC(fortunes->diagram->sites, points_count * sizeof(voronoi_site_t), "voronoi_site_t[]");
}

voronoi_diagram_t * create_voronoi_diagram(const point_t points[], const int points_count) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("create_voronoi_diagram") "\n");
#endif
    fortunes_structure_t fortunes;
    fortunes.tree = NULL;
    fortunes.edges = NULL;
    fortunes.lost_edges = NULL;
    fortunes.vertices = NULL;
    fortunes.diagram = malloc(sizeof(voronoi_diagram_t));
    DEBUG_MALLOC(fortunes.diagram, sizeof(voronoi_diagram_t), "voronoi_diagram_t");
    // количество сайтов известно заранее, + добавляем "фиктивный" сайт, чтобы не иметь дела с особым случаем (первые сайты на одной высоте). Потом мы его удалим.
    fortunes.diagram->site_count = points_count;
    fortunes.diagram->sites = malloc((points_count + 1) * sizeof(voronoi_site_t));
    DEBUG_MALLOC(fortunes.diagram->sites, (points_count+1) * sizeof(voronoi_site_t), "voronoi_site_t[]");
    pq_init(&fortunes.queue);
    
#if defined(DEBUG_OUTPUT)
    printf(ANSI_SECTION "Создаём события \"сайт\"" ANSI_RESET "\n");
#endif
    // загружаем все переданные точки в сайты и заполняем очередь событиями типа "сайт"
    voronoi_site_t * s = fortunes.diagram->sites;
    for (int i = 0; i < points_count; i++, s++) {
        s->point = points[i];
        s->vertices = NULL;
        s->edges = NULL;
#if defined(TCL_OUTPUT)
        snprintf(s->id, MAX_ID_LENGTH, "s%d", i);
#endif
        event_t * evt = malloc(sizeof(event_t));
        DEBUG_MALLOC(evt, sizeof(event_t), "event_t");
        evt->type = EVENT_TYPE_SITE;
        evt->site = s;
        pq_enqueue(&fortunes.queue, points[i].y, evt);
    }

    // добавляем "фиктивный" сайт, пользуясь тем, что s указывает куда нам надо
    add_dummy_site(s, points, points_count, &fortunes);

    while (!pq_empty(&fortunes.queue)) {
#if defined(DEBUG_OUTPUT)
        long double prio = pq_prio(&fortunes.queue);
        printf(ANSI_SECTION "%Lg: ", prio);
#endif
        event_t * evt = pq_dequeue(&fortunes.queue);
        if (evt->type == EVENT_TYPE_SITE) {
#if defined(DEBUG_OUTPUT)
            printf("сайт %s (%Lg, %Lg)" ANSI_RESET "\n", evt->site->id, evt->site->point.x, evt->site->point.y);
#endif
            handle_site_event(&fortunes, evt);
        } else {
#if defined(DEBUG_OUTPUT)
            printf("окружность (%Lg, %Lg; %Lg)" ANSI_RESET "\n", evt->x, evt->y, evt->r);
#endif
            handle_circle_event(&fortunes, evt);
        }
        DEBUG_FREE(evt, sizeof(event_t), "event_t");
        free(evt);
    }

#if defined(DEBUG_OUTPUT)
    printf(ANSI_SECTION "Очистка остатков дерева" ANSI_RESET "\n");
#endif
    // NULL здесь может быть только в том случае, если нет ни одного сайта; 
    // BEACHLINE_ARC здесь может быть только в одном случае: всего один сайт
    // Но с учётом того, что у нас был фиктивный сайт, их было как минимум два.

    // с каждой из оставшихся после главного цикла событий точкой излома связано полуребро, уходящее в бесконечность. 
    // функция рекурсивно удаляет эти точки излома и собирает эти полурёбра в lost_edges
    destroy_breakpoint_recursive(&fortunes, fortunes.tree);

    pq_destroy(&fortunes.queue);

    // удаляем "фиктивный" сайт, пользуясь тем, что s всё ещё указывает, куда надо
    delete_dummy_site(s, &fortunes, points_count);
    
    // TODO: вместо этого нужно обрезать и замкнуть диаграмму, добавив псевдо-полурёбра
    // заодно этот список перечисляет все неограниченные ячейки
#if defined(DEBUG_OUTPUT)
    printf("Полурёбра, уходящие в бесконечность:");
    while (!linked_list_empty(fortunes.lost_edges)) {
        voronoi_edge_t * lost_edge = linked_list_extract(&(fortunes.lost_edges));
        printf(" " CL_NEW("%s") "(" CL_OLD("%s") ")", lost_edge->id, lost_edge->site->id);
    }
    printf("\n");
#endif

// Копируем списки полурёбер и вершин в диаграмму TODO может сразу там и заполнять?
    fortunes.diagram->edge_count = linked_list_length(fortunes.edges);
    fortunes.diagram->edges = fortunes.edges;
    fortunes.diagram->vertice_count = linked_list_length(fortunes.vertices);
    fortunes.diagram->vertices = fortunes.vertices;
    
#if defined(DEBUG_OUTPUT)
    printf(ANSI_SECTION "Построение диаграммы завершено" ANSI_RESET "\n");
#endif
    return fortunes.diagram;
}

int destroy_voronoi_diagram(voronoi_diagram_t * diagram) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("destroy_voronoi_diagram") "\n");
    printf("Очистка вершин:");
#endif
    // TODO: очистить списки diagram->edges и diagram->vertices — как структру списка, так и данные. Внутри каждого vertices есть список sites, его тоже.
    while (!linked_list_empty(diagram->vertices)) {
        voronoi_vertex_t * vertex = (voronoi_vertex_t *) linked_list_extract(&(diagram->vertices));
#if defined(DEBUG_OUTPUT)
        printf(" " CL_DELETED("%s"), vertex->id);
#endif
        linked_list_flush(&(vertex->sites));
        linked_list_flush(&(vertex->edges_in));
        linked_list_flush(&(vertex->edges_out));
        DEBUG_FREE(vertex, sizeof(voronoi_vertex_t), "voronoi_vertex_t");
        free(vertex);
    }
#if defined(DEBUG_OUTPUT)
    printf("\nОчистка рёбер:");
#endif
    while(!linked_list_empty(diagram->edges)) {
        voronoi_edge_t * edge = (voronoi_edge_t *) linked_list_extract(&(diagram->edges));
#if defined(DEBUG_OUTPUT)
        printf(" " CL_DELETED("%s"), edge->id);
#endif
        DEBUG_FREE(edge, sizeof(voronoi_edge_t), "voronoi_edge_t");
        free(edge);
    }
#if defined(DEBUG_OUTPUT)
    printf("\nОчистка сайтов:");
#endif
    for (int i = 0; i < diagram->site_count; i++) {
#if defined(DEBUG_OUTPUT)
        printf(" " CL_DELETED("%s"), diagram->sites[i].id);
#endif
        linked_list_flush(&(diagram->sites[i].edges));
        linked_list_flush(&(diagram->sites[i].vertices));
    }
    DEBUG_FREE(diagram->sites, diagram->site_count * sizeof(voronoi_site_t), "voronoi_site_t[]");
    free(diagram->sites);
#if defined(DEBUG_OUTPUT)
    printf("\n");
#endif
    DEBUG_FREE(diagram, sizeof(voronoi_diagram_t), "voronoi_diagram_t");
    free(diagram);
#if defined(DEBUG_OUTPUT)
    printf("Память освобождена\n");
#endif
}

void check_invalidate_circle(beachline_object_t * arc) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("check_invalidate_circle(%s)") "\n", arc->id);
#endif
    if (arc->circle != NULL) {
#if defined(DEBUG_OUTPUT)
        printf("Отменяется событие " CL_DELETED("окружность (%Lg, %Lg; %Lg)") ", в котором должна была схлопнуться дуга " CL_QUESTION("%s @ %p") " (" CL_OLD("%s") ")\n",
               arc->circle->x, arc->circle->y, arc->circle->r, arc->id, arc, arc->site->id);
#endif
        arc->circle->invalid = true;
        arc->circle = NULL;
    }
}

void handle_site_event(fortunes_structure_t * fortunes, event_t * evt) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("handle_site_event(..., site=%s (%Lg, %Lg))") "\n", evt->site->id, evt->site->point.x, evt->site->point.y);
#endif
    
// добавляем фиктивный "нулевой" сайт, с координатой меньше, чем у извлечённого. Потом удалим.
    if (fortunes->tree == NULL) {
        fortunes->tree = create_arc(evt->site, NULL, TREE_PATH_LEFT);
#if defined(DEBUG_OUTPUT)
        printf("Создана дуга " CL_NEW("%s") "(" CL_OLD("%s") ") и инициализировано дерево\n", fortunes->tree->id, evt->site->id);
#endif
        return;
    }
    
    voronoi_site_t * new_site = evt->site;

    beachline_object_t * split_arc = find_arc_above(fortunes, new_site->point.x, new_site->point.y);
    voronoi_site_t * split_site = split_arc->site;
    // куда будем вставлять новосозданную структуру
    beachline_object_t * parent = split_arc->parent;
    tree_path_t path = split_arc->path;

#if defined(DEBUG_OUTPUT)
    if (parent == NULL) {
        // это возможно только если мы добавляем второй по счёту узел
        printf("Найдена дуга " CL_QUESTION("%s") " над сайтом " CL_QUESTION("%s") " (%Lg, %Lg); этот объект находится в корне дерева\n",
           split_arc->id, split_site->id, split_site->point.x, split_site->point.y);
    } else {
        printf("Найдена дуга " CL_QUESTION("%s") " над сайтом " CL_QUESTION("%s") " (%Lg, %Lg); это потомок " CL_QUESTION("%s") " в положении " CL_QUESTION("%s") "\n",
           split_arc->id, split_site->id, split_site->point.x, split_site->point.y, parent->id, (path==TREE_PATH_LEFT)?"слева":"справа");
    }
#endif

    // если с дугой было связано событие, отменяем его
    check_invalidate_circle(split_arc);

    // новая дуга разбивает старую, образуя две точки излома
    beachline_object_t * new_left_breakpoint = create_breakpoint(split_site, new_site);
    beachline_object_t * new_right_breakpoint = create_breakpoint(new_site, split_site);

    // структура дерева: rbp( lbp( sarc carc ) rarc) === sarc lbp carc rbp rarc 
    split_arc->parent = new_left_breakpoint;
    split_arc->path = TREE_PATH_LEFT;
    new_left_breakpoint->left_descendant = split_arc;
    beachline_object_t * new_center_arc = create_arc(new_site, new_left_breakpoint, TREE_PATH_RIGHT);
    new_left_breakpoint->right_descendant = new_center_arc;
        
    new_left_breakpoint->parent = new_right_breakpoint;
    new_left_breakpoint->path = TREE_PATH_LEFT;
    new_right_breakpoint->left_descendant = new_left_breakpoint;
    beachline_object_t * new_right_arc = create_arc(split_site, new_right_breakpoint, TREE_PATH_RIGHT);
    new_right_breakpoint->right_descendant = new_right_arc;
        
    if (split_arc->right_arc != NULL) {
        // если у старой дуги был сосед справа, это теперь сосед справа новой правой дуги, а новая правая дуга — его сосед слева
        split_arc->right_arc->left_arc = new_right_arc;
        new_right_arc->right_arc = split_arc->right_arc;
        new_right_arc->right_breakpoint = split_arc->right_breakpoint; // т.к. это кусок разбиваемой дуги, правая точка излома — правая точка излома той дуги
    }
    // береговая линия
    split_arc->right_arc = new_center_arc;
    new_center_arc->left_arc = split_arc;
    new_center_arc->right_arc = new_right_arc;
    new_right_arc->left_arc = new_center_arc;
    split_arc->right_breakpoint = new_center_arc->left_breakpoint = new_left_breakpoint; // старый объект-дуга назначается новой левой дугой
    new_right_arc->left_breakpoint = new_center_arc->right_breakpoint = new_right_breakpoint;

    voronoi_edge_t * right_edge = create_edge_pair(fortunes, new_site, split_site, NULL);
    //  точка излома ассоциируется с полуребром, связанным с правым сайтом, опять работает правило аргументов
    new_right_breakpoint->edge = right_edge;
    new_left_breakpoint->edge = right_edge->sibling;

#if defined(DEBUG_OUTPUT)
    printf("Создана структура: " CL_OLD("%s") "(" CL_OLD("%s") ") - " CL_NEW("%s") "(" CL_NEW("%s") ") - " CL_NEW("%s") "(" CL_QUESTION("%s") ") (%Lg, %Lg) - " CL_NEW("%s") "(" CL_NEW("%s") ") - " CL_NEW("%s") "(" CL_OLD("%s") ") (%Lg, %Lg)\n",
           split_arc->id, split_site->id, new_left_breakpoint->id, new_left_breakpoint->edge->id, new_center_arc->id, new_site->id, new_site->point.x,
           new_site->point.y, new_right_breakpoint->id, new_right_breakpoint->edge->id, new_right_arc->id, split_site->id, split_site->point.x, split_site->point.y);
#endif
    
    new_right_breakpoint->parent = parent;
    new_right_breakpoint->path = path;
    if (parent==NULL) {
        fortunes->tree = new_right_breakpoint;
    } else {
        if (path==TREE_PATH_LEFT)
            parent->left_descendant = new_right_breakpoint;
        else 
            parent->right_descendant = new_right_breakpoint;
    }
    
    // TODO балансировка дерева

    // проверяем дуги на предмет схлопывания
    check_add_circle(fortunes, split_arc/*, new_site->point.y*/);
    check_add_circle(fortunes, new_right_arc/*, new_site->point.y*/);
}

// TODO аргумент dy (текущее положение заметающей прямой) здесь может быть полезен для редкой проверки, которая стреляет только из-за вычислительной погрешности
void check_add_circle(fortunes_structure_t * fortunes, beachline_object_t * check_arc/*, const long double dy*/) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("check_add_circle(..., check_arc=%s)") "\n", check_arc->id/*, dy*/); // , dy=%Lg
#endif
    if (check_arc->left_arc == NULL || check_arc->right_arc == NULL) {
#if defined(DEBUG_OUTPUT)
        printf("Дуга " CL_QUESTION("%s") " над сайтом " CL_OLD("%s") " (%Lg, %Lg) находится на краю береговой линии — не может схлопнуться\n",
               check_arc->id, check_arc->site->id, check_arc->site->point.x, check_arc->site->point.y);
#endif
        return;
    }

    // TODO проверка, не было ли окружности через эти же сайты в другом порядке

    point_t pl = check_arc->left_arc->site->point;
    point_t pc = check_arc->site->point;
    point_t pr = check_arc->right_arc->site->point;

    // https://stackoverflow.com/questions/9612065/breakpoint-convergence-in-fortunes-algorithm/27882090#27882090
    // https://math.stackexchange.com/questions/1324179/how-to-tell-if-3-connected-points-are-connected-clockwise-or-counter-clockwise/1324213#1324213    
    long double D = (pr.x-pc.x)*(pl.y-pc.y) - (pl.x-pc.x)*(pr.y-pc.y);
    if (D <= 0) {
#if defined(DEBUG_OUTPUT)
        printf("Дуга " CL_QUESTION("%s") " над сайтом " CL_OLD("%s") " (%Lg, %Lg) не схлопывается\n",
               check_arc->id, check_arc->site->id, check_arc->site->point.x, check_arc->site->point.y);
#endif
        return;
    }
    
    D = 0.5/D; // чтобы делить на него один раз, а не трижды, и не делить на два
    long double rl = pl.x*pl.x+pl.y*pl.y;
    long double rc = pc.x*pc.x+pc.y*pc.y;
    long double rr = pr.x*pr.x+pr.y*pr.y;
    long double Dx = rl*(pc.y-pr.y) + rc*(pr.y-pl.y) + rr*(pl.y-pc.y); // коэффициент 1/2 встроен в D
    long double Dy = rl*(pc.x-pr.x) + rc*(pr.x-pl.x) + rr*(pl.x-pc.x); // коэффициент 1/2 встроен в D
    long double Dr = rl*(pc.x*pr.y-pr.x*pc.y) + rc*(pr.x*pl.y-pl.x*pr.y) + rr*(pl.x*pc.y-pc.x*pl.y);
    long double x = Dx*D;
    long double y = -Dy*D;
    long double r = sqrtl(x*x+y*y+2*Dr*D); // коэффициент 2 компенсирует 1/2 в D
    
#if defined(DEBUG_OUTPUT)
    printf("Дуга " CL_QUESTION("%s") " может схлопнуться в точке (" CL_NEW("%Lg") ", " CL_NEW("%Lg") ") на расстоянии " CL_NEW("%Lg") " от сайтов " CL_OLD("%s") " (%Lg, %Lg), " CL_QUESTION("%s") " (%Lg, %Lg) и " CL_OLD("%s") " (%Lg, %Lg), с приоритетом " CL_QUESTION("%Lg") "\n",
               check_arc->id, x, y, r, check_arc->left_arc->site->id, pl.x, pl.y, check_arc->site->id, pc.x, pc.y, check_arc->right_arc->site->id, pr.x, pr.y, y+r);
#endif

    // добавляем событие окружность с приоритетом y+r, связанное с дугой check_arc
    event_t * evt = malloc(sizeof(event_t));
    DEBUG_MALLOC(evt, sizeof(event_t), "event_t");
    evt->type = EVENT_TYPE_CIRCLE;
    evt->x = x;
    evt->y = y;
    evt->r = r;
    evt->arc = check_arc;
    evt->invalid = false;
    pq_enqueue(&fortunes->queue, y+r, evt);
    check_arc->circle = evt;
}

void handle_circle_event(fortunes_structure_t * fortunes, event_t * evt) {
#if defined(DEBUG_OUTPUT)
    // если событие отменено, дуга может быть уже освобождена, в этом случае разыменовывать указатель нельзя
    printf(CL_FUNC_ENTRY("handle_circle_event(x=%Lg, y=%Lg, r=%Lg, arc=@ %p)") "\n", evt->x, evt->y, evt->r, evt->arc);
#endif
    if (evt->invalid) {
#if defined(DEBUG_OUTPUT)
        // событие отменено, дуга может быть уже освобождена, в этом случае разыменовывать указатель нельзя
        printf("Окружность " CL_DELETED("(%Lg, %Lg; %Lg)") " (дуга @ " CL_DELETED("%p") ") — событие отменено\n", evt->x, evt->y, evt->r, evt->arc);
#endif
        return;
    }
    beachline_object_t * removed_arc = evt->arc;
    beachline_object_t * left_arc = removed_arc->left_arc;
    beachline_object_t * right_arc = removed_arc->right_arc;
    beachline_object_t * removed_breakpoint = removed_arc->parent;
    beachline_object_t * sibling = (removed_arc->path==TREE_PATH_LEFT)?removed_breakpoint->right_descendant:removed_breakpoint->left_descendant;
    tree_path_t new_sibling_path = removed_breakpoint->path;
    beachline_object_t * new_sibling_parent = removed_breakpoint->parent;
#if defined(DEBUG_OUTPUT)
    printf("Окружность (%Lg, %Lg; %Lg): схлопнулась дуга " CL_DELETED("%s") "(%s), которая была " CL_QUESTION("%s") " потомком узла " CL_DELETED("%s") "\n",
           evt->x, evt->y, evt->r, removed_arc->id, removed_arc->site->id, (removed_arc->path==TREE_PATH_LEFT)?"левым":"правым", removed_breakpoint->id);
    printf("Также удаляется узел " CL_DELETED("%s") "(%s). Сосед " CL_DELETED("%s") " " CL_MODIFIED("%s") "(%s), бывший " CL_QUESTION("%s") " потомком " CL_DELETED("%s") ", становится " CL_NEW("%s") " потомком " CL_MODIFIED("%s") "\n",
           removed_breakpoint->id, removed_breakpoint->edge->id, removed_arc->id, sibling->id, (sibling->type==BEACHLINE_ARC)?sibling->site->id:sibling->edge->id, (removed_arc->path==TREE_PATH_LEFT)?"правым":"левым", removed_breakpoint->id, (new_sibling_path==TREE_PATH_LEFT)?"левым":"правым", new_sibling_parent->id);
#endif
    
    // удаляем из дерева
    if (new_sibling_path == TREE_PATH_LEFT)
        new_sibling_parent->left_descendant = sibling;
    else
        new_sibling_parent->right_descendant = sibling;
    sibling->parent = new_sibling_parent;
    sibling->path = new_sibling_path;
    
    // находим общего предка левой и правой дуги - соседей удаляемой дуги по береговой линии, воспользуемся тем фактом, что обязательно
    // одним из объектов removed_arc->{left,right}_breakpoint равняется removed_breakpoint, а второй тогда — вот этот общий предок
    beachline_object_t * common_ancestor = (removed_arc->left_breakpoint==removed_breakpoint)?removed_arc->right_breakpoint:removed_arc->left_breakpoint;
    
    // удаляем дугу из береговой линии и устанавливаем common_ancestor в качестве новой точки излома между removed_arc->{left,right}_arc
    left_arc->right_arc = removed_arc->right_arc;
    right_arc->left_arc = removed_arc->left_arc;
    left_arc->right_breakpoint = right_arc->left_breakpoint = common_ancestor;
    common_ancestor->left_site = left_arc->site;
    common_ancestor->right_site = right_arc->site;
    
    // удаляем события окружность, которые могли включать левую или правую дуги
    check_invalidate_circle(left_arc);
    check_invalidate_circle(right_arc);
    
    // вершина
    voronoi_vertex_t * vertex = create_vertex(fortunes, evt->x, evt->y, evt->r);
    
    // новые полурёбра, связанные с обновлённой точкой излома
    voronoi_edge_t * right_edge = create_edge_pair(fortunes ,left_arc->site, right_arc->site, vertex);
    voronoi_edge_t * left_edge = right_edge->sibling;
    
    // эти полурёбра закончились в настоящей вершине, а их пары — начинаются
    voronoi_edge_t * l_edge = removed_arc->left_breakpoint->edge;
    voronoi_edge_t * r_edge = removed_arc->right_breakpoint->edge;
    l_edge->sibling->origin = r_edge->sibling->origin = l_edge->target = r_edge->target = vertex;
    
#if defined(DEBUG_OUTPUT)
//    printf("left_edge = %s(%s) | right_edge = %s(%s) | ", left_edge->id, left_edge->site->id, right_edge->id, right_edge->site->id);
//    printf("l_edge = %s(%s) sibling %s(%s) | ", l_edge->id, l_edge->site->id, l_edge->sibling->id, l_edge->sibling->site->id);
//    printf("r_edge = %s(%s) sibling %s(%s)\n", r_edge->id, r_edge->site->id, r_edge->sibling->id, r_edge->sibling->site->id);
    printf("Создана вершина " CL_NEW("%s") " (%Lg, %Lg; %Lg), в ней замыкаются полурёбра:\n",
           vertex->id, vertex->point.x, vertex->point.y, vertex->distance);
    printf("    " CL_OLD("%s") " (%Lg, %Lg): " CL_NEW("%s") " → " CL_MODIFIED("%s") ",\n",
           left_arc->site->id, left_arc->site->point.x, left_arc->site->point.y, left_edge->id, l_edge->sibling->id);
    printf("    " CL_OLD("%s") " (%Lg, %Lg): " CL_MODIFIED("%s") " → " CL_MODIFIED("%s") ",\n",
           removed_arc->site->id, removed_arc->site->point.x, removed_arc->site->point.y, l_edge->id, r_edge->sibling->id);
    printf("    " CL_OLD("%s") " (%Lg, %Lg): " CL_MODIFIED("%s") " → " CL_NEW("%s") ".\n",
           right_arc->site->id, right_arc->site->point.x, right_arc->site->point.y, r_edge->id, right_edge->id);
           
#endif
    
    // замыкаем полурёбра
    left_edge->next = l_edge->sibling;
    l_edge->sibling->previous = left_edge;
    right_edge->previous = r_edge;
    r_edge->next = right_edge;
    l_edge->next = r_edge->sibling;
    r_edge->sibling->previous = l_edge;
    
    // Записываем в вершину информацию о рёбрах
    linked_list_append(&(vertex->edges_out), l_edge->sibling);
    linked_list_append(&(vertex->edges_out), r_edge->sibling);
    linked_list_append(&(vertex->edges_out), right_edge);
    linked_list_append(&(vertex->edges_in), left_edge);
    linked_list_append(&(vertex->edges_in), l_edge);
    linked_list_append(&(vertex->edges_in), r_edge);
    linked_list_append(&(vertex->sites), left_arc->site);
    linked_list_append(&(vertex->sites), removed_arc->site);
    linked_list_append(&(vertex->sites), right_arc->site);
    
    // Записываем в сайты информацию о вершине
    linked_list_append(&(left_arc->site->vertices), vertex);
    linked_list_append(&(removed_arc->site->vertices), vertex);
    linked_list_append(&(right_arc->site->vertices), vertex);

    // обновлённая точка излома трассирует уже новое ребро — привязываем так, чтобы с сайта мы видели обход вдоль рёбер против часовой стрелки, "налево"
    common_ancestor->edge = right_edge;
    
#if defined(DEBUG_OUTPUT)
    printf("Соседи старой дуги соприкоснулись, обновилась точка излома между ними: " CL_MODIFIED("%s") " (" CL_OLD("%s")") - " CL_MODIFIED("%s") "(" CL_NEW("%s") ") - " CL_MODIFIED("%s") " (" CL_OLD("%s") ")\n",
           left_arc->id, left_arc->site->id, common_ancestor->id, common_ancestor->edge->id, right_arc->id, right_arc->site->id);
#endif
    
    // освобождаем память — на эти объекты больше ссылок ниоткуда нет
    destroy_arc(removed_arc);
    destroy_breakpoint_only(removed_breakpoint);
    
    // проверяем новые тройки на предмет схлопывания
    check_add_circle(fortunes, left_arc/*, evt->y+evt->r*/);
    check_add_circle(fortunes, right_arc/*, evt->y+evt->r*/);
}

// TODO: site и parent тут const, но discarded qualifier
beachline_object_t * create_arc(voronoi_site_t * site, beachline_object_t * parent, const tree_path_t path) {
    static int arc_id = 0;
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("create_arc(site=%s (%Lg, %Lg), ...)") "\n", site->id, site->point.x, site->point.y);
#endif
    beachline_object_t * arc = malloc(sizeof(beachline_object_t));
    DEBUG_MALLOC(arc, sizeof(beachline_object_t), "beachline_object_t");
#if defined(DEBUG_OUTPUT)
    snprintf(arc->id, MAX_ID_LENGTH, "a%d", arc_id++);
#endif
    arc->type = BEACHLINE_ARC;
    arc->site = site;
    arc->parent = parent;
    arc->path = path;
    arc->left_breakpoint = NULL;
    arc->right_breakpoint = NULL;
    arc->left_arc = NULL;
    arc->right_arc = NULL;
    arc->circle = NULL;
    return arc;
}

long double sqrl(const long double a) {
    return a*a;
}

long double parabolas_left_cross_point(const long double xl, const long double yl, const long double xr, const long double yr, const long double y) {
    return (xr*(y-yl)-xl*(y-yr)-sqrtl((sqrl(xl-xr)+sqrl(yl-yr))*(y-yl)*(y-yr)))/(yr-yl);
}

beachline_object_t * find_arc_above(const fortunes_structure_t * fortunes, const long double x, const long double y) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("find_arc_above(..., x=%Lg, y=%Lg)") "\n", x, y);
#endif
    beachline_object_t * item = fortunes->tree;
    while (item->type != BEACHLINE_ARC) {
        point_t lp = item->left_site->point;
        point_t rp = item->right_site->point;
#if defined(DEBUG_OUTPUT)
        printf("Точка излома " CL_QUESTION("%s") " между дуг сайта " CL_OLD("%s") " (%Lg, %Lg) и " CL_OLD("%s") " (%Lg, %Lg)\n",
               item->id, item->left_site->id, lp.x, lp.y, item->right_site->id, rp.x, rp.y);
#endif
        long double xlr = (lp.y==rp.y)?(lp.x+rp.x)/2:parabolas_left_cross_point(lp.x, lp.y, rp.x, rp.y, y);
        item = (x<xlr)?item->left_descendant:item->right_descendant; 
#if defined(DEBUG_OUTPUT)
        printf("Точка излома (" CL_NEW("%Lg") ", %Lg), сайт (" CL_QUESTION("%Lg") ", %Lg) - переход " CL_QUESTION("%s") " к " CL_QUESTION("%s") "\n",
               xlr, sqrl(xlr-rp.x)/(2*(rp.y-y)) + (rp.y+y)/2, x, y, (x<xlr)?"налево":"направо", item->id);
#endif
    }
    return item;
}

// TODO: а нужна ли вообще эта функция?
void destroy_arc(beachline_object_t * arc) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("destroy_arc(%s): site=%s (%Lg, %Lg)") "\n", arc->id, arc->site->id, arc->site->point.x, arc->site->point.y);
#endif
    DEBUG_FREE(arc, sizeof(beachline_object_t), "beachline_object_t");
    free(arc);
}

beachline_object_t * create_breakpoint(voronoi_site_t * left_site, voronoi_site_t * right_site) {
    static int breakpoint_id = 0;
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("create_breakpoint(left_site=%s (%Lg, %Lg), right_site=%s (%Lg, %Lg), ...)") "\n",
           left_site->id, left_site->point.x, left_site->point.y, right_site->id, right_site->point.x, right_site->point.y);
#endif
    beachline_object_t * breakpoint = malloc(sizeof(beachline_object_t));
    DEBUG_MALLOC(breakpoint, sizeof(beachline_object_t), "beachline_object_t");
#if defined(DEBUG_OUTPUT)
    snprintf(breakpoint->id, MAX_ID_LENGTH, "b%d", breakpoint_id++);
#endif
    breakpoint->type = BEACHLINE_BREAKPOINT;
    breakpoint->left_site = left_site;
    breakpoint->right_site = right_site;
    // инициализировать остальные поля NULL нет смысла, поскольку мы их всё равно сразу же заполним
    return breakpoint;
}

// TODO: а нужна ли вообще эта функция?
void destroy_breakpoint_only(beachline_object_t * breakpoint) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("destroy_breakpoint_only(%s): edge=%s, left_site=%s (%Lg, %Lg), right_site=%s (%Lg, %Lg)") "\n", breakpoint->id, breakpoint->edge->id,
           breakpoint->left_site->id, breakpoint->left_site->point.x, breakpoint->left_site->point.y,
           breakpoint->right_site->id, breakpoint->right_site->point.x, breakpoint->right_site->point.y);
    printf("точка излома " CL_DELETED("%s") " удалена\n", breakpoint->id);
#endif
    DEBUG_FREE(breakpoint, sizeof(beachline_object_t), "beachline_object_t");
    free(breakpoint);
}

void destroy_breakpoint_recursive(fortunes_structure_t * fortunes, beachline_object_t * breakpoint) {
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("destroy_breakpoint_recursive(..., %s): edge=%s, left_site=%s (%Lg, %Lg), right_site=%s (%Lg, %Lg)") "\n",
           breakpoint->id, breakpoint->edge->id,
           breakpoint->left_site->id, breakpoint->left_site->point.x, breakpoint->left_site->point.y,
           breakpoint->right_site->id, breakpoint->right_site->point.x, breakpoint->right_site->point.y);
#endif

    if (breakpoint->left_descendant->type == BEACHLINE_BREAKPOINT)
        destroy_breakpoint_recursive(fortunes, breakpoint->left_descendant);
    else
        destroy_arc(breakpoint->left_descendant);

    if (breakpoint->right_descendant->type == BEACHLINE_BREAKPOINT)
        destroy_breakpoint_recursive(fortunes, breakpoint->right_descendant);
    else
        destroy_arc(breakpoint->right_descendant);
    // если мы удаляем точку излома через эту функцию, то связанную с ней полубесконечную границу нужно добавить в соответствующий список
    linked_list_append(&(fortunes->lost_edges), breakpoint->edge);
#if defined(DEBUG_OUTPUT)
    printf("точка излома " CL_DELETED("%s") " удалена рекурсивно\n", breakpoint->id);
#endif
    DEBUG_FREE(breakpoint, sizeof(beachline_object_t), "beachline_object_t");
    free(breakpoint);
}

// создаёт связанную пару полурёбер, возвращает то из них, которое связано с правым сайтом (второе можно найти как sibling). left_target можно задать NULL
voronoi_edge_t * create_edge_pair(fortunes_structure_t * fortunes, voronoi_site_t * left_site, voronoi_site_t * right_site, voronoi_vertex_t * left_target) {
    static int edge_id = 0;
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("create_edge_pair(..., %s, %s, %s)") "\n",
           (left_site==NULL)?"NULL":left_site->id, (right_site==NULL)?"NULL":right_site->id, (left_target==NULL)?"NULL":left_target->id);
#endif
    voronoi_edge_t * left_edge = malloc(sizeof(voronoi_edge_t));
    voronoi_edge_t * right_edge = malloc(sizeof(voronoi_edge_t));
    DEBUG_MALLOC(left_edge, sizeof(voronoi_edge_t), "voronoi_edge_t");
    DEBUG_MALLOC(right_edge, sizeof(voronoi_edge_t), "voronoi_edge_t");
#if defined(TCL_OUTPUT)
    snprintf(left_edge->id, MAX_ID_LENGTH, "e%d", edge_id++);
    snprintf(right_edge->id, MAX_ID_LENGTH, "e%d", edge_id++);
#endif
    left_edge->sibling = right_edge;
    right_edge->sibling = left_edge;
    left_edge->site = left_site;
    right_edge->site = right_site;
    left_edge->target = right_edge->origin = left_target;
    right_edge->previous = left_edge->previous = right_edge->next = left_edge->next = NULL; // TODO: надо ли это инициализировать?
    right_edge->target = left_edge->origin = NULL; // TODO: надо ли это инициализировать?

    // Привязываем границы к сайтам
    linked_list_append(&(left_site->edges), left_edge);
    linked_list_append(&(right_site->edges), right_edge);

    // TODO: добавлять в список границ в диаграмме здесь или там?
    linked_list_append(&(fortunes->edges), left_edge);
    linked_list_append(&(fortunes->edges), right_edge);
    return right_edge;
}

voronoi_vertex_t * create_vertex(fortunes_structure_t * fortunes, const long double x, const long double y, const long double r) {
    static int vertex_id = 0;
#if defined(DEBUG_OUTPUT)
    printf(CL_FUNC_ENTRY("create_vertex(..., %Lg, %Lg, %Lg)") "\n", x, y, r);
#endif
    voronoi_vertex_t * vertex = malloc(sizeof(voronoi_vertex_t));
    DEBUG_MALLOC(vertex, sizeof(voronoi_vertex_t), "voronoi_vertex_t");
#if defined(TCL_OUTPUT)
    snprintf(vertex->id, MAX_ID_LENGTH, "v%d", vertex_id++);
#endif
    vertex->point.x = x;
    vertex->point.y = y;
    vertex->distance = r;
    vertex->sites = NULL;
    vertex->edges_in = NULL;
    vertex->edges_out = NULL;
    linked_list_append(&(fortunes->vertices), vertex);
    return vertex;
}
