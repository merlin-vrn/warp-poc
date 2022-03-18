#if !defined(_FORTUNES_H)
#define _FORTUNES_H

#include "linked_list.h"

#if defined(DEBUG_OUTPUT)
// Для TCL нам потребуется задать сайтам, вершинам и полурёбрам символьные индексы. Для отладки такие индексы потребуются всем.
#define TCL_OUTPUT
#endif

#if defined(TCL_OUTPUT)
#define MAX_ID_LENGTH 8
#endif

typedef struct {
    long double x;
    long double y;
} point_t;

typedef struct voronoi_site_s voronoi_site_t;
typedef struct voronoi_vertex_s voronoi_vertex_t;
typedef struct voronoi_edge_s voronoi_edge_t;

struct voronoi_site_s {
#if defined(TCL_OUTPUT)
    char id[MAX_ID_LENGTH];
#endif
    point_t point;
// ссылки на полурёбра и вершины
    linked_list_t * vertices;
    linked_list_t * edges;
};

struct voronoi_vertex_s {
#if defined(TCL_OUTPUT)
    char id[MAX_ID_LENGTH];
#endif
    point_t point;
    long double distance;
// ссылки на соприкасающиеся сайты, полурёбра входящие и выходящие
    linked_list_t * sites;
    linked_list_t * edges_in;
    linked_list_t * edges_out;
};

struct voronoi_edge_s {
#if defined(TCL_OUTPUT)
    char id[MAX_ID_LENGTH];
#endif
    voronoi_edge_t * sibling, * previous, * next;
    voronoi_vertex_t * origin, * target;
    voronoi_site_t * site;
};

typedef struct voronoi_diagram_s {
    voronoi_site_t * sites;
    linked_list_t * edges;
    linked_list_t * vertices;
    int site_count;
    int edge_count;
    int vertice_count;
} voronoi_diagram_t;

voronoi_diagram_t * create_voronoi_diagram(const point_t points[], const int points_count);
int destroy_voronoi_diagram(voronoi_diagram_t * diagram);

#endif
