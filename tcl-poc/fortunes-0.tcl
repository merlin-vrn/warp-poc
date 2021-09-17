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
proc handle_site_event { state_name x y } {
    upvar 1 $state_name state
    
    set site [new_site]
    set state($site) [list $x $y]
    puts "Новый сайт: [c]$site[n] ($x, $y)"
    
    # 1. Если дерево T отсутствует, инициализируем его объектом "дуга", связанным с этим сайтом site. И выходим
    if {![info exists state(T)]} {
        set state(T) [dict create type arc id [new_arc] site $site]
        puts "    инициализируем дерево: T => $state(T)"
        return
    }
    
    # 2. Ищем в T дугу, находящуюся непосредственно над site
    set cur T ;# начиная с дерева
    while {[dict get $state($cur) type]!="arc"} {
        # т.е. type здесь - node
        puts "    [y]$cur[n] => $state($cur)"
        lassign [dict get $state($cur) breakpoint] larc rarc ;# это ссылки соответственно на дугу "слева" и "справа" от границы, и нам нужно узнать, какая из них наша
        set lsite [dict get $state($larc) site]
        set rsite [dict get $state($rarc) site]
        lassign [dict get $state($lsite)] xr yr
        lassign [dict get $state($rsite)] xr yr
        puts "    граница между дуг $larc от сайта $lsite ($xl, $yl) и $rarc от сайта $rsite ($xr, $yr)"
        # в уравнении два корня, если поменять порядок точек - корни меняются местами. Здесь нужен со знаком "-" перед sqrt (TODO: поподробнее)
        set xlr [expr {($xr*($y-$yl)-$xl*($y-$yr)-hypot($xl-$xr,$yl-$yr)*sqrt(($y-$yl)*($y-$yr)))/($yr-$yl)}] ;# точка пересечения парабол
        set cur [dict get $state($cur) [expr {($x<$xlr)?"left":"right"}]]
        puts "    [c]$x[n] vs xlr = [y]$xlr[n]"
    }
    puts "    [c]$cur[n] => $state($cur) - дуга над этим сайтом"
    

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
    
    # Дуги
    nextid new_arc a
    nextid new_site s

    # 1. Инициализируем очередь событиями типа "сайт" — входные точки
    foreach p $points {
        lassign $p x y
        events add $y "site" $x
    }

    puts "Очередь на [y]старте[n]: [events dump]"

    # 2. Пока есть события,
    while {[events length]>0} { 
        # 3. Выбираем событие с наибольшей координатой y (приоритетом)
        lassign [events get] evt_prio evt_type evt_data
        # 4. Если это событие "сайт",
        if {$evt_type=="site"} {
            # 5. Обрабатываем как сайт
            handle_site_event state $evt_data $evt_prio ;# для события типа "сайт" x=data, y=prio
        } else { ;# evt_type==circle
            # 6. Обрабатываем как окружность
            handle_circle_event state $evt_data
        } ;# evt_type==?
        # TODO: в обработчики мы *наверняка* напихаем ещё аргументов
    }

    # 7.
    # 8.
    return {}
}

set V [compute_voronoi_diagram $points]
puts "Диаграмма Вороного: $V"
