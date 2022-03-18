#include <math.h>
#include <stdio.h>

#include "fortunes.h"

#include "ansi.h"
#define CL_NEW(n) ANSI_FG(ANSI_BRIGHT(ANSI_GREEN)) n ANSI_FG_DEFAULT
#define CL_MODIFIED(n) ANSI_FG(ANSI_BRIGHT(ANSI_MAGENTA)) n ANSI_FG_DEFAULT
#define CL_OLD(n) ANSI_FG(ANSI_BRIGHT(ANSI_BLUE)) n ANSI_FG_DEFAULT
#define CL_QUESTION(n) ANSI_FG(ANSI_BRIGHT(ANSI_YELLOW)) n ANSI_FG_DEFAULT
#define CL_DELETED(n) ANSI_FG(ANSI_BRIGHT(ANSI_RED)) n ANSI_FG_DEFAULT
#define ANSI_IMPORTANT ANSI_BG(ANSI_RED) ANSI_FG(ANSI_BRIGHT(ANSI_WHITE))
#define ANSI_SECTION ANSI_BG(ANSI_GREEN) ANSI_FG(ANSI_BRIGHT(ANSI_WHITE))
#define CL_FUNC_ENTRY(n) ANSI_FG(ANSI_BRIGHT(ANSI_BLACK)) n ANSI_RESET

int main(int argc, char* argv[], char* env[]) {
    point_t points[] = { {.x=4, .y=2}, {.x=5, .y=5}, {.x=3, .y=9}, {.x=8, .y=2}, {.x=7, .y=6} };
/*
    point_t points[] = {
        {.x=  0, .y=  0}, {.x=  0, .y=479}, {.x= 40, .y=  0}, {.x= 40, .y=479}, {.x= 80, .y=  0}, {.x= 80, .y=479}, {.x=120, .y=  0}, {.x=120, .y=479},
        {.x=160, .y=  0}, {.x=160, .y=479}, {.x=200, .y=  0}, {.x=200, .y=479}, {.x=240, .y=  0}, {.x=240, .y=479}, {.x=280, .y=  0}, {.x=280, .y=479},
        {.x=320, .y=  0}, {.x=320, .y=479}, {.x=360, .y=  0}, {.x=360, .y=479}, {.x=400, .y=  0}, {.x=400, .y=479}, {.x=440, .y=  0}, {.x=440, .y=479},
        {.x=480, .y=  0}, {.x=480, .y=479}, {.x=520, .y=  0}, {.x=520, .y=479}, {.x=560, .y=  0}, {.x=560, .y=479}, {.x=600, .y=  0}, {.x=600, .y=479},
        {.x=  0, .y= 40}, {.x=639, .y= 40}, {.x=  0, .y= 80}, {.x=639, .y= 80}, {.x=  0, .y=120}, {.x=639, .y=120}, {.x=  0, .y=160}, {.x=639, .y=160},
        {.x=  0, .y=200}, {.x=639, .y=200}, {.x=  0, .y=240}, {.x=639, .y=240}, {.x=  0, .y=280}, {.x=639, .y=280}, {.x=  0, .y=320}, {.x=639, .y=320},
        {.x=  0, .y=360}, {.x=639, .y=360}, {.x=  0, .y=400}, {.x=639, .y=400}, {.x=  0, .y=440}, {.x=639, .y=440}, {.x= 92, .y= 91}, {.x=546, .y= 92},
        {.x=104, .y=396}, {.x=529, .y=381}, {.x=246, .y=353}, {.x=273, .y=353}, {.x=368, .y=353}, {.x=399, .y=353}, {.x=275, .y=265}, {.x=316, .y=264},
        {.x=275, .y=242}, {.x=344, .y=230}, {.x=342, .y=171}, {.x=275, .y=164}, {.x=355, .y=198}, {.x=342, .y=257}, {.x=246, .y=265}, {.x=247, .y=138},
        {.x=358, .y=149}, {.x=245, .y=240}, {.x=359, .y=250}, {.x=384, .y=198}, {.x=273, .y=203}, {.x=245, .y=191}, {.x=313, .y=138}, {.x=310, .y=241},
        {.x=309, .y=162}, {.x=378, .y=170}, {.x=377, .y=228}, {.x=245, .y=217}, {.x=246, .y=166}
    };
    point_t points[] = {
        {.x=5, .y=0}, {.x=0, .y=5}, {.x=10, .y=5}, {.x=5, .y=10}, {.x=1, .y=2}, {.x=8, .y=1},
        {.x=9, .y=8}, {.x=2, .y=9}, {.x=9, .y=2}, {.x=1, .y=8}, {.x=2, .y=1}, {.x=8, .y=9}
    };
*/

    voronoi_diagram_t * diagram = create_voronoi_diagram(points, sizeof(points)/sizeof(points[0]));

    printf("Диаграмма: %d сайтов, %d вершин, %d полурёбер\n", diagram->site_count, diagram->vertice_count, diagram->edge_count);
    voronoi_site_t * site = diagram->sites;
    for (int i = 0; i < diagram->site_count; i++, site++) {
#if defined(TCL_OUTPUT)
        printf(CL_NEW("%s") " (%Lg, %Lg):", site->id, site->point.x, site->point.y);
#else
        printf(CL_NEW("%p") " (%Lg, %Lg):", site, site->point.x, site->point.y);
#endif
        if (site->vertices) {
            voronoi_edge_t * e0 = (voronoi_edge_t *) site->edges->data;
            voronoi_edge_t * e1;
            if (!e0->next) {
                // это последнее ребро в незамкнутой цепочке
                e1 = e0;
                // находим первое ребро
                while (e0->previous)
                    e0 = e0->previous;
            } else {
                // это не последнее ребро, либо цепочка замкнута
                e1 = e0->next;
                // находим последнее, либо опознаём цикл
                while (e1->next && e1->next != e0)
                    e1 = e1->next;
                if (!e1->next) // цикл не замкнут
                    while (e0->previous)
                        e0 = e0->previous;
            }
            if (e0->previous)
#if defined(TCL_OUTPUT)
                printf(" " CL_MODIFIED("%s") " (%Lg, %Lg; %Lg)", e0->origin->id, e0->origin->point.x, e0->origin->point.y, e0->origin->distance);
#else
                printf(" " CL_MODIFIED("%p") " (%Lg, %Lg; %Lg)", e0->origin, e0->origin->point.x, e0->origin->point.y, e0->origin->distance);
#endif
            else
                printf(" " CL_DELETED("∞"));
            while (e0 && e0!=e1) {
#if defined(TCL_OUTPUT)
                printf(" " CL_QUESTION("%s") "-" CL_OLD("%s") "(" CL_OLD("%s") ") " CL_MODIFIED("%s") " (%Lg, %Lg; %Lg)",
                       e0->id, e0->sibling->id, e0->sibling->site->id, e0->target->id, e0->target->point.x, e0->target->point.y, e0->target->distance);
#else
                printf(" " CL_QUESTION("%p") "-" CL_OLD("%p") "(" CL_OLD("%p") ") " CL_MODIFIED("%p") " (%Lg, %Lg; %Lg)",
                       e0, e0->sibling, e0->sibling->site, e0->target, e0->target->point.x, e0->target->point.y, e0->target->distance);
#endif
                e0 = e0->next;
            }
            if (e1->next) {
#if defined(TCL_OUTPUT)
                printf(" " CL_QUESTION("%s") "-" CL_OLD("%s") "(" CL_OLD("%s") ") %s...",
                       e1->id, e1->sibling->id, e1->sibling->site->id, e1->target->id);
#else
                printf(" " CL_QUESTION("%p") "-" CL_OLD("%p") "(" CL_OLD("%p") ") %p...",
                       e1, e1->sibling, e1->sibling->site, e1->target);
#endif
            } else {
#if defined(TCL_OUTPUT)
                printf(" " CL_QUESTION("%s") "-" CL_OLD("%s") "(" CL_OLD("%s") ") " CL_DELETED("∞"),
                       e1->id, e1->sibling->id, e1->sibling->site->id);
#else
                printf(" " CL_QUESTION("%p") "-" CL_OLD("%p") "(" CL_OLD("%p") ") " CL_DELETED("∞"),
                       e1, e1->sibling, e1->sibling->site);
#endif
            }
        } else {
            // вершин у ячейки нет. Бывает...
            linked_list_t * edges = site->edges;
            while (!linked_list_empty(edges)) {
                voronoi_edge_t * edge = linked_list_walk(&edges);
#if defined(TCL_OUTPUT)
                printf(" " CL_QUESTION("%s") "-" CL_OLD("%s") "(" CL_OLD("%s") ")", edge->id, edge->sibling->id, edge->sibling->site->id);
#else
                printf(" " CL_QUESTION("%p") "-" CL_OLD("%p") "(" CL_OLD("%p") ")", edge, edge->sibling, edge->sibling->site);
#endif
            }
        }
        printf("\n");
    }

    destroy_voronoi_diagram(diagram);
    return 0;
}
