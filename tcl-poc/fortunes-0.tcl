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

# Поиск окружности (центр и радиус), проходящей через все три точки
proc find_circle { x1 y1 x2 y2 x3 y3 } {
#    puts "    [R]$x1 $y1 $x2 $y2 $x3 $y3[n]"
    set D [expr {$x1*($y2-$y3)+$x2*($y3-$y1)+$x3*($y1-$y2)}]
    #     | x₁  y₁  1 |           | x₁²+y₁²  y₁  1 |            | x₁²+y₁²  x₁  1 |         | x₁²+y₁²  x₁  y₁ |
    # D = | x₂  y₂  1 |    Dx = ½ | x₂²+y₂²  y₂  1 |     Dy = ½ | x₂²+y₂²  x₂  1 |    Dr = | x₂²+y₂²  x₂  y₂ |
    #     | x₃  y₃  1 |           | x₃²+y₃²  y₃  1 |            | x₃²+y₃²  x₃  1 |         | x₃²+y₃²  x₃  y₃ |
    if {$D==0} {
        # точки принадлежат одной прямой
        return 0
    }
    set _D [expr {1.0/$D}]
    set r1 [expr {$x1*$x1+$y1*$y1}]
    set r2 [expr {$x2*$x2+$y2*$y2}]
    set r3 [expr {$x3*$x3+$y3*$y3}]
#    puts "    [G]D=$D, 1/D=$_D, x₁²+y₁²=$r1, x₂²+y₂²=$r2, x₃²+y₃²=$r3[n]"
    set Dx [expr {($r1*($y2-$y3)+$r2*($y3-$y1)+$r3*($y1-$y2))/2}]
    set Dy [expr {($r1*($x2-$x3)+$r2*($x3-$x1)+$r3*($x1-$x2))/2}]
    set Dr [expr {$r1*($x2*$y3-$x3*$y2)+$r2*($x3*$y1-$x1*$y3)+$r3*($x1*$y2-$x2*$y1)}]
#    puts "    [G]Dx=$Dx, Dy=$Dy, Dr=$Dr[n]"
    set x [expr {$Dx*$_D}]
    set y [expr {-$Dy*$_D}]
    set r [expr {sqrt($x*$x+$y*$y+$Dr*$_D)}]
    return [list $x $y $r]
}

# обрабатывает событие "сайт", расположенный в точке x y
proc handle_site_event { state_name x y } {
    upvar 1 $state_name state
    
    set site [new_site]
    set state($site) [list $x $y]
    puts "Новый сайт: [c]$site[n] ($x, $y)"
    
    # 1. Если дерево T отсутствует, инициализируем его объектом "дуга", связанным с этим сайтом site. И выходим
    if {![info exists state(T)]} {
        set arc [new_arc]
        set state($arc) [dict create site $site parent T path {}]
        puts "Новая дуга: [c]$arc[n] (сайт $site)"
        set state(T) $arc
        puts "    инициализируем дерево: T => $state(T)"
        return
    }

    # 2. Ищем в T дугу, находящуюся непосредственно над site
    set item $state(T) ;# начиная с дерева
    while {![dict exists $state($item) site]} { ;# у дуги всегда есть сайт, её порождающий, а у границы — никогда нет такого свойства
        lassign [dict get $state($item) breakpoint] lsite rsite ;# это ссылки соответственно на дугу "слева" и "справа" от границы, и нам нужно узнать, какая из них наша
        lassign [dict get $state($lsite)] xl yl
        lassign [dict get $state($rsite)] xr yr
        puts "    [y]$item[n] => $state($item) - граница между дуг сайта [y]$lsite[n] ($xl, $yl) и сайта [y]$rsite[n] ($xr, $yr)"
        if {$yr!=$yl} {
            # в уравнении два корня, если поменять порядок точек - корни меняются местами. Здесь нужен со знаком "-" перед sqrt (TODO: почему именно этот)
            set xlr [expr {($xr*($y-$yl)-$xl*($y-$yr)-hypot($xl-$xr,$yl-$yr)*sqrt(($y-$yl)*($y-$yr)))/($yr-$yl)}] ;# точка пересечения парабол
        } else {
            set xlr [expr {($xl+$xr)/2}] ;# если они находятся на одной высоте, это "вертикальное" ребро
        }
        set subpath [expr {($x<$xlr)?"left":"right"}]
        set item [dict get $state($item) $subpath]
        puts "    граница: [m]$xlr[n], сайт: [c]$x[n] — переход [y]$subpath[n] к [m]$item[n]"
    }

    # Сайт, порождающий эту дугу
    set split_site [dict get $state($item) site]
    # Положение дуги в дереве
    set parent [dict get $state($item) parent]
    set subpath [dict get $state($item) path]

    puts "    [b]$item[n] => $state($item) - дуга над сайтом [b]$split_site[n]; она является потомком [y]$parent[n] в положении \"[y]$subpath[n]\""
    # TODO Если к этой дуге было привязано событие circle — помечаем его как "ложную тревогу"
    if {[dict exists $state($item) circle]} {
        puts "    [R]окружность [y][dict get $state($item) circle][n]"
    }

    # 3. Заменяем найденный объект поддеревом из двух или трёх дуг
    set arcs_to_check {} ;# сюда положим дуги, которые могут вызвать событие окружность (проверим в п. 5)

    # Собираем новое поддерево взамен убираемого листика
    if {$y==[lindex $state($split_site) 1]} { ;# если новый сайт и разделяемый лежат на одной высоте, то у нас получится две дуги, а не три
        puts "    сайты лежат на одной высоте; по горизонтали: новый [y]$x[n], старый [y][lindex $state($split_site) 0][n]"
        set narc [new_arc]
        set state($narc) [dict create site $site]
        set redge [new_edge]
        set state($redge) [dict create parent $parent path $subpath]
        dict set state($item) parent $redge
        dict set state($narc) parent $redge
        if {$x>[lindex $state($split_site) 0]} { ;# Новая дуга справа
            if {[dict exists $state($item) right]} {
                # Если у старой дуги справа был сосед, 
                set neigh [dict get $state($item) right]
                # теперь это сосед справа для новой дуги,
                dict set state($narc) right $neigh
                # а его сосед слева, соответственно, новая дуга
                dict set state($neigh) left $narc
            }
            # Соседство: narc - сосед item справа, item - сосед narc слева 
            dict set state($item) right $narc
            dict set state($narc) left $item
            # Сосед item слева, если он есть — остаётся как был
            dict set state($item) path left
            dict set state($narc) path right
            dict set state($redge) breakpoint [list $split_site $site]
            dict set state($redge) left $item
            dict set state($redge) right $narc
            set _info "слева старая дуга [b]$item[n] над сайтом [b]$split_site[n], справа новая дуга [c]$narc[n] над сайтом [c]$site[n]"
        } else { ;# Новая дуга слева
            if {[dict exists $state($item) left]} {
                # Если у старой дуги слева был сосед, 
                set neigh [dict get $state($item) left]
                # теперь это сосед слева для новой дуги,
                dict set state($narc) left $neigh
                # а его сосед справа, соответственно, новая дуга
                dict set state($neigh) right $narc
            }
            # Соседство: narc - сосед item слева, item - сосед narc справа 
            dict set state($item) left $narc
            dict set state($narc) right $item
            dict set state($item) path right
            dict set state($narc) path left
            # Сосед item справа, если он есть — остаётся как был
            dict set state($redge) breakpoint [list $site $split_site]
            dict set state($redge) left $narc
            dict set state($redge) right $item
            set _info "слева новая дуга [c]$narc[n] над сайтом [c]$site[n], справа старая дуга [b]$item[n] над сайтом [b]$split_site[n]"
        }
        puts "Граница [c]$redge[n] ($state($redge)): $_info"
        lappend arcs_to_check $item
        lappend arcs_to_check $narc
    } else {
        puts "    новая дуга разбивает старую на две и оказывается в середине"
        # Строим структуру из трёх дуг, боковые — кусочки старой дуги, цетральная — новая дуга
        # левый кусочек — оставляем идентификатор от старой дуги item
        set carc [new_arc]
        set state($carc) [dict create site $site] ;# средний кусочек — дуга от нового сайта
        set ledge [new_edge]
        set state($ledge) [dict create breakpoint [list $split_site $site] left $item right $carc]
        puts "Левая граница [c]$ledge[n] ($state($ledge)): слева старая дуга [b]${item}[n] над сайтом [b]$split_site[n], справа новая дуга [c]${carc}[n] над сайтом [c]$site[n]"
        set rarc [new_arc]
        set state($rarc) [dict create site $split_site] ;# правый кусочек — "копия" левого
        set redge [new_edge]
        set state($redge) [dict create breakpoint [list $site $split_site] left $ledge right $rarc parent $parent path $subpath]
        puts "Правая граница [c]$redge[n] ($state($redge)): слева поддерево [m]${ledge}[n] и сайт [c]$site[n], справа копия старой дуги [c]${rarc}[n] над сайтом [b]$split_site[n]"
        # Обновляем соседей
        if {[dict exists $state($item) right]} {
            # если у старой дуги был сосед справа,
            set neigh [dict get $state($item) right]
            # это теперь сосед справа её клона,
            dict set state($rarc) right $neigh
            # а его сосед слева, соответственно, теперь этот клон
            dict set state($neigh) left $rarc
        }
        dict set state($item) right $carc
        dict set state($carc) left $item
        dict set state($carc) right $rarc
        dict set state($rarc) left $carc
        # Левый сосед item, если есть, остаётся без изменений
        dict set state($ledge) parent $redge
        dict set state($ledge) path left
        dict set state($item) parent $ledge
        dict set state($item) path left
        dict set state($carc) parent $ledge
        dict set state($carc) path right
        dict set state($rarc) parent $redge
        dict set state($rarc) path right
        lappend arcs_to_check $item
        # средняя дуга (от нового сайта) пока никак не может "схлопнуться" — она сейчас растёт, по бокам у неё кусочки одной и той же параболы
        lappend arcs_to_check $rarc
    }
    
    # Вставляем его в новую позицию
    if {$subpath=={}} {
        puts "    вставляем в корень дерева [m]T[n]"
        set state($parent) $redge
    } else {
        puts "    вставляем в [g]${parent}[n] ($state($parent)) в положение \"[m]$subpath[n]\""
        dict set state($parent) $subpath $redge
    }
    
    # TODO балансировка дерева
    
    # TODO 4. Создаём в выходной структуре полурёбра
    
    # 5. Проверяем две вновь возникшие тройки соседних дуг на предмет схождения точек разрыва. Добавляем для таких событие "окружность"
    # TODO: избежать вычисления одной и той же окружности дважды
    # TODO: вот у нас два раза возникла одна и та же окружность, "справа" и "слева". Какую из дуг она схлопнет? Обе?
    foreach arc $arcs_to_check {
        if {!([dict exists $state($arc) left]&&[dict exists $state($arc) right])} {
            # эта дуга расположена на краю береговой линии
            continue
        }
        set larc [dict get $state($arc) left]
        set rarc [dict get $state($arc) right]
        puts "Проверяем тройку [y]$larc[n]-[y]$arc[n]-[y]$rarc[n]"
        set lsite [dict get $state($larc) site]
        set site [dict get $state($arc) site]
        set rsite [dict get $state($rarc) site]
        set c [find_circle {*}[dict get $state($lsite)] {*}[dict get $state($site)] {*}[dict get $state($rsite)]]
        if {$c==0} {
            puts "    окружность, содержащая сайты [m]$lsite[n] ([dict get $state($lsite)]), [m]$site[n] [dict get $state($site)], [m]$rsite[n] ([dict get $state($rsite)]), не существует"
        } else {
            lassign $c cx cy r
            puts "    окружность, содержащая сайты [m]$lsite[n] ([dict get $state($lsite)]), [m]$site[n] [dict get $state($site)], [m]$rsite[n] ([dict get $state($rsite)]): ([y]$cx $cy $r[n])"
            # Если нижняя точка окружности выше текущего события, вообще не паримся
            if {$cy+$r<$y} {
                continue
            }
            # Приоритетом события "окружность" будет её нижняя точка, а остальную информацию добавим на всякий случай
            events add [expr {$cy+$r}] "circle" $cx $cy $r $arc
            # TODO: Как-нибудь запишем в дугу, что с ней связано событие-окружность, вообще-то тут нужна ссылка на событие, вдруг его придётся инвалидировать
            dict set state($arc) circle [list $cx $cy $r]
        }
    }
    
}

# обрабатывает событие "окружность"
proc handle_circle_event { state_name d } {
    upvar 1 $state_name state

    puts "Новая окружность: [c]$d[n]"
}

# Рассчитывает диаграмму Вороного для набора точек points
proc compute_voronoi_diagram { points } {
    # стр. 157
    # Очередь с приоритетами
    priority_queue events
    
    # Дуги
    nextid new_arc a
    nextid new_site s
    nextid new_edge e

    # 1. Инициализируем очередь событиями типа "сайт" — входные точки
    foreach p $points {
        lassign $p x y
        events add $y "site" $x
    }

    puts "Очередь на [y]старте[n]: [events dump]"

    # 2. Пока есть события,
    while {[events length]>0} { 
        # 3. Выбираем событие с наибольшей координатой y (приоритетом)
        set evt_data [lassign [events get] evt_prio evt_type]
        # 4. Если это событие "сайт",
        if {$evt_type=="site"} {
            # 5. Обрабатываем как сайт
            handle_site_event state $evt_data $evt_prio ;# для события типа "сайт" x=data, y=prio
        } else { ;# evt_type==circle
            # 6. Обрабатываем как окружность
            handle_circle_event state $evt_data
        } ;# evt_type==?
        # TODO: в обработчики мы *наверняка* напихаем ещё аргументов
        
        # поиск самой левой дуги
        set arc a0
        while {[dict exists $state($arc) left]} {
            set arc [dict get $state($arc) left]
        }
        # распечатка "береговой линии"
        puts "Береговая линия:"
        while {[dict exists $state($arc) right]} {
            set site [dict get $state($arc) site ]
            puts "    [m]$arc[n] [b]$site[n] ([dict get $state($site)])"
            set arc [dict get $state($arc) right]
        }
        set site [dict get $state($arc) site ]
        puts "    [m]$arc[n] [b]$site[n] ([dict get $state($site)])"
    }

    puts [array get state]
    # 7.
    # 8.
    return {}
}

set V [compute_voronoi_diagram $points]
puts "Диаграмма Вороного: $V"
