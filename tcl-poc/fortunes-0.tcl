#!/usr/bin/env tclsh

# Построение диаграммы Вороного по алгоритму Форчуна

# поддержка разноцветного вывода
source "ansi.tcl"
namespace import ansi::*

# вспомогательные функции, структуры данных
# пока что всё в одном файле, потом возможно разделим
source "primitives.tcl"

# Рамки, за которые выйти невозможно — для обрезания рёбер, уходящих в бесконечность
set width 640
set height 480
# Здесь предполагается, что обрезание будет делаться по рамке {-1 -1 640 480}

# Загружаем тестовый набор точек
source "points.tcl"

# обрабатывает событие "сайт", расположенный в точке x y
proc handle_site_event { x y } {
    puts "Новый [y]сайт[n]: [c]$x $y[n]"
}

# обрабатывает событие "окружность"
proc handle_circle_event { d } {
    puts "Новая [y]окружность[n]: [c]$d[n]"
}

# Рассчитывает диаграмму Вороного для набора точек points
proc compute_voronoi_diagram { points } {
    # стр. 157

    # Очередь с приоритетами
    priority_queue events

    # 1. Инициализируем очередь событиями типа "сайт" — входные точки
    foreach p $points {
        lassign $p x y
        events add $y "site" $x
    }

    puts "Очередь на [y]старте[n]: [events dump]"

    # 2. Пока есть события,
    while {[events len]>0} { 
        # 3. Выбираем событие с наибольшей координатой y (приоритетом)
        lassign [events get] evt_prio evt_type evt_data
        # 4. Если это событие "сайт",
        if {$evt_type=="site"} {
            # 5. Обрабатываем как сайт
            handle_site_event $evt_data $evt_prio ;# для события типа "сайт" x=data, y=prio
        } else { ;# evt_type==circle
            # 6. Обрабатываем как окружность
            handle_circle_event $evt_data
        } ;# evt_type==?
        # TODO: в обработчики мы *наверняка* напихаем ещё аргументов
    }

    # 7.
    # 8.
    return {}
}

set V [compute_voronoi_diagram $points]
puts "Диаграмма Вороного: $V"
