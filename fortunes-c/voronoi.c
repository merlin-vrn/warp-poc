#include <tcl.h>

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "fortunes.h"
#include "linked_list.h"

static int Fortunes(ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);

int DLLEXPORT Voronoi_Init(Tcl_Interp *interp) {
    if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
        return TCL_ERROR;
    }
    if (Tcl_PkgProvide(interp, "Voronoi", "1.0") == TCL_ERROR) {
        return TCL_ERROR;
    }
    Tcl_CreateObjCommand(interp, "fortunes", Fortunes, NULL, NULL);
    return TCL_OK;
}

static int Fortunes(ClientData cdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "list");
        return TCL_ERROR;
    }
    // первый аргумент - список списков по два double в каждом

    int length;
    Tcl_Obj ** elem;
    if (Tcl_ListObjGetElements(interp, objv[1], &length, &elem) != TCL_OK) {
        return TCL_ERROR;
    }

    // сюда сложим данные
    point_t * points = malloc(length * sizeof(point_t));

    // обходим внешний список
    for (struct {int idx; Tcl_Obj ** pelem;} loop = {0, elem}; loop.idx<length; loop.idx++, loop.pelem++) {
        // в каждом подсписок
        int sublen;
        Tcl_Obj ** subelem;
        if (Tcl_ListObjGetElements(interp, *loop.pelem, &sublen, &subelem) != TCL_OK) {
            free(points);
            return TCL_ERROR;
        }
        // если там не два элемента, ошибка с кастомным сообщением
        if (sublen != 2) {
            Tcl_AddErrorInfo(interp, "wrong input list format: each item must contain exactly 2 double elements");
            free(points);
            return TCL_ERROR;
        }
        double t;
        // если элементы не читаются как double, ошибка (текст ошибки будет встроеный: expected floating-point number but got "...")
        if (Tcl_GetDoubleFromObj(interp, subelem[0], &t) != TCL_OK) {
            free(points);
            return TCL_ERROR;
        }
        points[loop.idx].x = t;
        if (Tcl_GetDoubleFromObj(interp, subelem[1], &t) != TCL_OK) {
            free(points);
            return TCL_ERROR;
        }
        points[loop.idx].y = t;
    }

    // создаём диаграмму
    voronoi_diagram_t * diagram = create_voronoi_diagram(points, length);
    free(points);

    // строим объект TCL с диаграммой
    Tcl_Obj *tcl_diagram = Tcl_NewDictObj();

    // сайты
    for (struct {int idx; voronoi_site_t * site;} a = {0, diagram->sites}; a.idx< diagram->site_count; a.idx++, a.site++) {
        Tcl_Obj * tcl_site = Tcl_NewDictObj();
        Tcl_Obj * tcl_list;

        // координаты
        tcl_list = Tcl_NewListObj(2, NULL);
        Tcl_ListObjAppendElement(interp, tcl_list, Tcl_NewDoubleObj(a.site->point.x));
        Tcl_ListObjAppendElement(interp, tcl_list, Tcl_NewDoubleObj(a.site->point.y));
        Tcl_DictObjPut(interp, tcl_site, Tcl_NewStringObj("point", -1), tcl_list);

        linked_list_t * c_llist;
        // вершины
        tcl_list = Tcl_NewListObj(0, NULL);
        c_llist = a.site->vertices;
        while (!linked_list_empty(c_llist))
            Tcl_ListObjAppendElement(interp, tcl_list, Tcl_NewStringObj(((voronoi_vertex_t *)linked_list_walk(&c_llist))->id, -1));
        Tcl_DictObjPut(interp, tcl_site, Tcl_NewStringObj("vertices", -1), tcl_list);

        // рёбра
        tcl_list = Tcl_NewListObj(0, NULL);
        c_llist = a.site->edges;
        while (!linked_list_empty(c_llist))
            Tcl_ListObjAppendElement(interp, tcl_list, Tcl_NewStringObj(((voronoi_edge_t *)linked_list_walk(&c_llist))->id, -1));
        Tcl_DictObjPut(interp, tcl_site, Tcl_NewStringObj("edges", -1), tcl_list);

        Tcl_DictObjPut(interp, tcl_diagram, Tcl_NewStringObj(a.site->id, -1), tcl_site);
    }

    linked_list_t * list_idx;
    // рёбра
    list_idx = diagram->edges;
    while (!linked_list_empty(list_idx)) {
        voronoi_edge_t * edge = (voronoi_edge_t *) linked_list_walk(&list_idx);
        Tcl_Obj * tcl_edge = Tcl_NewDictObj();

        Tcl_DictObjPut(interp, tcl_edge, Tcl_NewStringObj("site", -1), Tcl_NewStringObj(edge->site->id, -1));
        if (edge->sibling)
            Tcl_DictObjPut(interp, tcl_edge, Tcl_NewStringObj("sibling", -1), Tcl_NewStringObj(edge->sibling->id, -1));
        if (edge->previous) {
            Tcl_DictObjPut(interp, tcl_edge, Tcl_NewStringObj("previous", -1), Tcl_NewStringObj(edge->previous->id, -1));
            Tcl_DictObjPut(interp, tcl_edge, Tcl_NewStringObj("origin", -1), Tcl_NewStringObj(edge->origin->id, -1));
        }
        if (edge->next) {
            Tcl_DictObjPut(interp, tcl_edge, Tcl_NewStringObj("next", -1), Tcl_NewStringObj(edge->next->id, -1));
            Tcl_DictObjPut(interp, tcl_edge, Tcl_NewStringObj("target", -1), Tcl_NewStringObj(edge->target->id, -1));
        }

        Tcl_DictObjPut(interp, tcl_diagram, Tcl_NewStringObj(edge->id, -1), tcl_edge);
    }

    // вершины
    list_idx = diagram->vertices;
    while (!linked_list_empty(list_idx)) {
        voronoi_vertex_t * vertex = (voronoi_vertex_t *) linked_list_walk(&list_idx);
        Tcl_Obj * tcl_vertex = Tcl_NewDictObj();
        Tcl_Obj * tcl_list;

        // координаты
        tcl_list = Tcl_NewListObj(2, NULL);
        Tcl_ListObjAppendElement(interp, tcl_list, Tcl_NewDoubleObj(vertex->point.x));
        Tcl_ListObjAppendElement(interp, tcl_list, Tcl_NewDoubleObj(vertex->point.y));
        Tcl_DictObjPut(interp, tcl_vertex, Tcl_NewStringObj("point", -1), tcl_list);

        // расстояние до сайтов
        Tcl_DictObjPut(interp, tcl_vertex, Tcl_NewStringObj("distance", -1), Tcl_NewDoubleObj(vertex->distance));

        linked_list_t * c_llist;
        // сайты
        tcl_list = Tcl_NewListObj(0, NULL);
        c_llist = vertex->sites;
        while (!linked_list_empty(c_llist))
            Tcl_ListObjAppendElement(interp, tcl_list, Tcl_NewStringObj(((voronoi_site_t *)linked_list_walk(&c_llist))->id, -1));
        Tcl_DictObjPut(interp, tcl_vertex, Tcl_NewStringObj("sites", -1), tcl_list);

        // рёбра входящие
        tcl_list = Tcl_NewListObj(0, NULL);
        c_llist = vertex->edges_in;
        while (!linked_list_empty(c_llist))
            Tcl_ListObjAppendElement(interp, tcl_list, Tcl_NewStringObj(((voronoi_edge_t *)linked_list_walk(&c_llist))->id, -1));
        Tcl_DictObjPut(interp, tcl_vertex, Tcl_NewStringObj("edges_in", -1), tcl_list);

        // рёбра выходящие
        tcl_list = Tcl_NewListObj(0, NULL);
        c_llist = vertex->edges_out;
        while (!linked_list_empty(c_llist))
            Tcl_ListObjAppendElement(interp, tcl_list, Tcl_NewStringObj(((voronoi_edge_t *)linked_list_walk(&c_llist))->id, -1));
        Tcl_DictObjPut(interp, tcl_vertex, Tcl_NewStringObj("edges_out", -1), tcl_list);

        Tcl_DictObjPut(interp, tcl_diagram, Tcl_NewStringObj(vertex->id, -1), tcl_vertex);
    }

    // уничтожаем диаграмму
    destroy_voronoi_diagram(diagram);

    Tcl_SetObjResult(interp, tcl_diagram);
    return TCL_OK;
}
