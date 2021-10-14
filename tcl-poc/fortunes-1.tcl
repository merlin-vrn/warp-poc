namespace eval Fortunes {

namespace export compute_voronoi_diagram
    
# Построение диаграммы Вороного по алгоритму Форчуна

# вспомогательные функции, структуры данных
# пока что всё в одном файле, потом возможно разделим
source "primitives.tcl"

# если к дуге arc привязано событие окружность, то удаляем его и помечаем событие, как невалидное
proc check_invalidate_circle { state_name arc } {
    upvar 1 $state_name state

    if {[dict exists $state($arc) circle]} {
        set circle [dict get $state($arc) circle]
        if {$state($circle)!=0} { set state($circle) 0 }
        # отвязываем дугу от события
        dict unset state($arc) circle
    }
}

# находит дугу, находящуюся над точкой x, когда заметающая линия находится в положении y
proc find_arc_above { state_name x y } {
    upvar 1 $state_name state

    set item $state(T) ;# начиная с дерева
    while {![dict exists $state($item) site]} { ;# у дуги всегда есть свойство — порождающий сайт, а у точки излома нет такого свойства
        # item - точка излома между дуг, образованных сайтами lsite и rsite
        lassign [dict get $state($item) breakpoint] lsite rsite ;# это ссылки соответственно на сайты, порождающие дуги "слева" и "справа" от точки излома
        lassign [dict get $state($lsite)] xl yl
        lassign [dict get $state($rsite)] xr yr
        if {$yr!=$yl} {
            # в уравнении два корня, если поменять порядок точек - корни меняются местами. Здесь нужен со знаком "-" перед sqrt (TODO: почему именно этот)
            set xlr [expr {($xr*($y-$yl)-$xl*($y-$yr)-hypot($xl-$xr,$yl-$yr)*sqrt(($y-$yl)*($y-$yr)))/($yr-$yl)}] ;# точка пересечения парабол
        } else {
            set xlr [expr {($xl+$xr)/2}] ;# если фокусы находятся на одной высоте, точка пересечения у парабол тоже одна и она посередине
        }
        # переходим к тому дочернему элементу, в который попадает сайт
        set subpath [expr {($x<$xlr)?"left":"right"}]
        set item [dict get $state($item) $subpath]
    }
    return $item
}

# обрабатывает событие "сайт", расположенный в точке x y
proc handle_site_event { state_name site } {
    upvar 1 $state_name state
    
    lassign $state($site) x y
    
    # 1. Если дерево T отсутствует, инициализируем его объектом "дуга", связанным с этим сайтом site. И выходим
    if {![info exists state(T)]} {
        set arc [new_arc]
        set state($arc) [dict create site $site parent T path {}]
        set state(T) $arc
        return
    }

    # 2. Ищем в T дугу, находящуюся непосредственно над site
    set split_arc [find_arc_above state $x $y]
    
    # Сайт, порождающий эту дугу
    set split_site [dict get $state($split_arc) site]
    lassign $state($split_site) sx sy

    # Положение дуги в дереве
    set parent [dict get $state($split_arc) parent]
    set subpath [dict get $state($split_arc) path]

    # Если к этой дуге было привязано событие circle — помечаем его как "ложную тревогу"
    check_invalidate_circle state $split_arc

    # 3. Заменяем найденный объект поддеревом из двух или трёх дуг, 4. Создаём в выходной структуре полурёбра
    set arcs_to_check {} ;# накопитель для дуг, которые мы будем проверять на "схлопывание" в событии окружность (п. 5)

    # Собираем новое поддерево взамен убираемого листика
    if {$y==$sy} { ;# если новый сайт и разделяемый лежат на одной высоте, то у нас получится две дуги, а не три
        # Это может произойти только в самом начале, пока мы проходим по сайтам с самой малой координатой y и она у них всех совпадает
        # В любом другом случае над сайтом, совпадающем с другим по высоте, всегда найдётся для разбиения дуга, порождённая каким-то из сайтов с ординатой меньше.
        # Создаётся два бесконечных вертикальных полуребра, хотя точка излома одна (правая). С левым полуребром не связывается никакая точка излома.
        set le [new_edge]
        set re [new_edge]
        set narc [new_arc]
        set rbp [new_breakpoint]
        set state($narc) [dict create site $site parent $rbp]
        # Направления полурёбер выбираются такими, чтобы они обходили сайт против часовой стрелки. Т.е. если смотреть на полуребро из сайта, оно смотрит налево.
        # le: 0, vy; re: 0, -vy
#        set vy [expr {abs($x-$sx)}]
        # точка излома ассоциируется с полуребром, связанным с правым сайтом
        set state($rbp) [dict create parent $parent path $subpath edge $re]
        # второе полуребро запоминаем в структуре, чтобы потом не отыскивать
        lappend state(infinite_edges) $le
        set state($le) [dict create sibling $re] ;# новые полурёбра являются двойниками друг друга
        set state($re) [dict create sibling $le] ;# координата y точки начала неизвестна :(
        dict set state($split_arc) parent $rbp
        if {$x>$sx} { ;# Новая дуга справа
            if {[dict exists $state($split_arc) right]} { ;# Если у старой дуги был сосед справа, 
                set neigh [dict get $state($split_arc) right] 
                dict set state($narc) right $neigh ;# теперь это сосед справа для новой дуги,
                dict set state($neigh) left $narc ;# а его сосед слева, соответственно, новая дуга
                dict set state($narc) rbp [dict get $state($split_arc) rbp] ;# и этот атрибут должен был быть задан, переносим
            }
            # Соседство: narc - сосед split_arc справа, split_arc - сосед narc слева 
            dict_mset state($split_arc) right $narc path left rbp $rbp
            dict_mset state($narc) left $split_arc path right lbp $rbp
            dict_mset state($rbp) breakpoint [list $split_site $site] left $split_arc right $narc
            dict set state($le) site $split_site
            dict set state($re) site $site 

            # ссылка на полурёбра из ячейки TODO: сделать нормальную структуру s* 
            lappend state(E$split_site) $le
            lappend state(E$site) $re
        } else { ;# Новая дуга слева
            if {[dict exists $state($split_arc) left]} { ;# Если у старой дуги слева был сосед, 
                set neigh [dict get $state($split_arc) left]
                dict set state($narc) left $neigh ;# теперь это сосед слева для новой дуги,
                dict set state($neigh) right $narc ;# а его сосед справа, соответственно, новая дуга
                dict set state($narc) lbp [dict get $state($split_arc) lbp] ;# и этот атрибут должен был быть задан, переносим
            }
            # Соседство: narc - сосед split_arc слева, split_arc - сосед narc справа 
            dict_mset state($split_arc) left $narc path right lbp $rbp
            dict_mset state($narc) right $split_arc path left rbp $rbp
            dict_mset state($rbp) breakpoint [list $site $split_site] left $narc right $split_arc 
            dict set state($le) site $site 
            dict set state($re) site $split_site

            # ссылка на полурёбра из ячейки TODO: сделать нормальную структуру s* 
            lappend state(E$site) $le
            lappend state(E$split_site) $re
        }
        lappend arcs_to_check $split_arc
        lappend arcs_to_check $narc
    } else {
        # Строим структуру из трёх дуг: слева оставляем структуру от разбиваемой дуги split_arc, в середине новая дуга, справа клон разбиваемой дуги
        set carc [new_arc]
        set rarc [new_arc]
        set lbp [new_breakpoint]
        set rbp [new_breakpoint]
        set le [new_edge]
        set re [new_edge]

        # Координаты новых полурёбер: точка начала x, py=(x-sx)²/(2(sy-y))+(sy+y)/2
        # Направления полурёбер выбираются такими, чтобы они обходили сайт против часовой стрелки. Т.е. если смотреть на полуребро из сайта, оно смотрит налево.
        # Вектор направления le: vx=sy-y, vy=x-sx, re: в противоположную сторону
        
        set state($le) [dict create sibling $re site $site]
        set state($re) [dict create sibling $le site $split_site]

        # ссылка на полурёбра из ячейки TODO: сделать нормальную структуру s* 
        lappend state(E$site) $le
        lappend state(E$split_site) $re

        set state($carc) [dict create site $site left $split_arc right $rarc parent $lbp path right lbp $lbp rbp $rbp] ;# средний кусочек — дуга от нового сайта
        # точка излома ассоциируется с полуребром, связанным с правым сайтом в изломе, в данном случае с site связан le
        set state($lbp) [dict create breakpoint [list $split_site $site] left $split_arc right $carc  parent $rbp path left edge $le]
        set state($rarc) [dict create site $split_site left $carc parent $rbp path right lbp $rbp] ;# правый кусочек — "копия" левого
        # точка излома ассоциируется с полуребром, связанным с правым сайтом в изломе, в данном случае с split_site связан re
        set state($rbp) [dict create breakpoint [list $site $split_site] left $lbp right $rarc parent $parent path $subpath edge $re]
        # Обновляем соседей
        if {[dict exists $state($split_arc) right]} { ;# если у разбиваемой дуги был сосед справа,
            set neigh [dict get $state($split_arc) right]
            dict set state($rarc) right $neigh ;# это теперь сосед справа её клона,
            dict set state($neigh) left $rarc ;# а его сосед слева, соответственно, теперь клон
            dict set state($rarc) rbp [dict get $state($split_arc) rbp] ;# и этот атрибут должен был быть задан, переносим
        }
        dict_mset state($split_arc) right $carc parent $lbp path left rbp $lbp ;# правый сосед разбиваемой дуги теперь новая дуга carc
        lappend arcs_to_check $split_arc
        lappend arcs_to_check $rarc
    }
    
    # Вставляем его в новую позицию
    if {$subpath=={}} {
        set state($parent) $rbp
    } else {
        dict set state($parent) $subpath $rbp
    }
    
    # TODO балансировка дерева
    
    # 5. Проверяем две вновь возникшие тройки соседних дуг на предмет слопывания средней. Добавляем для таких событие "окружность"
    foreach arc $arcs_to_check {
        check_add_circle state $arc $y
    }
}

# Проверяет тройку дуг с указанной дугой в середине на предмет схлопывания и добавляет событие "окружность".
proc check_add_circle { state_name carc y } {
    upvar 1 $state_name state

    if {!([dict exists $state($carc) left]&&[dict exists $state($carc) right])} { return 0 } ;# эта дуга расположена на краю береговой линии
    
    # Дуги слева и справа
    set larc [dict get $state($carc) left]
    set rarc [dict get $state($carc) right]

    set lsite [dict get $state($larc) site]
    set csite [dict get $state($carc) site]
    set rsite [dict get $state($rarc) site]

    set circle [new_circle $lsite $csite $rsite]
    # проверяем, не было ли уже окружности через эти же сайты, возможно, перечисленные в другом порядке
    if {[info exists state($circle)]} { return 0 } ;# окружность через эти сайты мы уже обрабатывали

    # Точки излома слева и справа хранятся в самой дуге. Полурёбра привязаны к точкам излома. Всё это нужно только для того, чтобы распечатывать красивые сообщения.
    # parent(carc) и nca(larc,rarc) — это тот же самый набор, что и nca(larc,carc) и nca(carc,rarc), но неизвестно, в каком порядке
    # теоретически, от перестановки левой и правой точки излома вообще ничего не должно измениться
    set lbp [dict get $state($carc) lbp]
    set rbp [dict get $state($carc) rbp]
    set le [dict get $state($lbp) edge]
    set re [dict get $state($rbp) edge]

    # Координаты сайтов
    lassign $state($lsite) xl yl
    lassign $state($csite) xc yc
    lassign $state($rsite) xr yr

    # https://stackoverflow.com/questions/9612065/breakpoint-convergence-in-fortunes-algorithm/27882090#27882090
    # https://math.stackexchange.com/questions/1324179/how-to-tell-if-3-connected-points-are-connected-clockwise-or-counter-clockwise/1324213#1324213
    # TODO: эта же штука потом вычисляется в find_circle. Как-то этого надо избежать. Также, где-то всё-таки происходит потеря точности, что проявляется в одном тесте
    set D [expr {($xr-$xc)*($yl-$yc)-($xl-$xc)*($yr-$yc)}]
    #set D [expr {$xl*($yc-$yr)+$xc*($yr-$yl)+$xr*($yl-$yc)}]
    if {$D<=0} { return 0 } ;# полурёбра параллельны (0) или расходятся (-)
    
    lassign [find_circle $xr $yr $xc $yc $xl $yl] cx cy r

    # Приоритетом события "окружность" будет её нижняя точка
    set state($circle) [list $cx $cy $r $carc]
    events add [expr {$cy+$r}] "circle" $circle
    
    dict set state($carc) circle $circle

    return $circle
}

# обрабатывает событие "окружность"
proc handle_circle_event { state_name circle } {
    upvar 1 $state_name state

    if {$state($circle)==0} { return } ;# отменённое событие
    lassign $state($circle) x y r carc

    set larc [dict get $state($carc) left]
    set rarc [dict get $state($carc) right]

    set parent [dict get $state($carc) parent]
    set subpath [dict get $state($carc) path]
    if {$subpath=="left"} { set sibpath "right" } else { set sibpath "left" }

    set parparent [dict get $state($parent) parent]
    set parsubpath [dict get $state($parent) path]
    if {$parsubpath=="left"} { set parsibpath "right" } else { set parsibpath "left" }

    set sibling [dict get $state($parent) $sibpath]

    # 1. Удаляем схлопнувшуюся дугу и всё, что с ней связано
    
    # parent и nca(larc,rarc) — это тот же самый набор, что и nca(larc,carc) и nca(carc,rarc), но неизвестно, в каком порядке
    # точки излома хранятся в дуге
    set lbp [dict get $state($carc) lbp]
    set rbp [dict get $state($carc) rbp]
    
    # 1.1 удаляем из береговой линии
    dict set state($larc) right $rarc
    dict set state($rarc) left $larc
    # 1.2 удаляем из дерева
    dict set state($parparent) $parsubpath $sibling 
    dict_mset state($sibling) parent $parparent path $parsubpath
    # 1.3 обновляем точки излома
    # Находим общего предка новых "соседних" дуг и устанавливаем их сайты в качестве точки излома этого предка.
    # Это та точка излома из lbp, rpb, которая не parent.
    set nca [if {$lbp==$parent} {set rbp} else {set lbp}] ;# это типа тернарный оператор, ага, так можно было
    
    set lsite [dict get $state($larc) site]
    set csite [dict get $state($carc) site]
    set rsite [dict get $state($rarc) site]

    dict set state($nca) breakpoint [list $lsite $rsite]
    
    # этот ncа теперь их точка излома с соответствующей стороны
    dict set state($larc) rbp $nca
    dict set state($rarc) lbp $nca
    
    # 1.4 Удаляем все события окружность, которые могли включать удалённую дугу
    check_invalidate_circle state $larc
    check_invalidate_circle state $rarc
    
    # 2. добавить вершину и полурёбра

    # вершина имеет отношение к трём сайтам, которые определяют эту окружность
    set vertex [new_vertex]
    set state($vertex) [dict create point [list $x $y] r $r sites [list $lsite $csite $rsite]]

    # эти полурёбра заканчиваются в настоящей вершине
    set l_edge [dict get $state($lbp) edge]
    set r_edge [dict get $state($rbp) edge]
    # эти начинаются
    set l_edge_sibling [dict get $state($l_edge) sibling]
    set r_edge_sibling [dict get $state($r_edge) sibling]
    
    # в этой вершине начинается новое полуребро, к которому привяжем $nca, и заканчивается новый же его двойник
    set le [new_edge]
    set re [new_edge]

    set state($le) [dict create sibling $re site $lsite target $vertex next $l_edge_sibling]
    set state($re) [dict create sibling $le site $rsite origin $vertex prev $r_edge]
    
    # ссылка на полурёбра и вершину из ячеек TODO: сделать вместо этого структуру state(s*) подобно state(v*): point [list x y] edges [list ...] vertices [list ...]
    lappend state(E$lsite) $le
    lappend state(E$rsite) $re
    lappend state(V$lsite) $vertex
    lappend state(V$csite) $vertex
    lappend state(V$rsite) $vertex

    # привязываем так, чтобы с сайта мы видели обход вдоль рёбер против часовой стрелки, "налево"
    dict set state($nca) edge $re
    
    # эти два старых полуребра в настоящей вершине замкнулись друг на друга
    dict_mset state($l_edge) target $vertex next $r_edge_sibling
    dict_mset state($r_edge_sibling) origin $vertex prev $l_edge
    
    # эти два старых полуребра замкнулись на новые полурёбра
    dict_mset state($r_edge) target $vertex next $re
    dict_mset state($l_edge_sibling) origin $vertex prev $le
    
    # запишем в вершину, какие полурёбра в ней начинаются и какие заканчиваются, в том же порядке, что и соответствующие сайты
    dict_mset state($vertex) sources [list $l_edge_sibling $r_edge_sibling $re] sinks [list $le $l_edge $r_edge]

    # parent больше не точка излома, избавляемся от неё
    unset state($parent)
    
    # и дуга arc больше не существует, схлопнулась
    unset state($carc)
    
    # событие окружность сработало, чтобы не мозолило глаза, избавляемся
    set state($circle) 0
    
    # 3. Новые тройки добавляем как события окружность
    check_add_circle state $larc [expr {$y+$r}]
    check_add_circle state $rarc [expr {$y+$r}]
}

proc new_circle {args} {
    set c "c"
    foreach s [lsort -dictionary $args] {
        set c "${c}_[string range $s 1 end]" ;# отрезаем префикс "s" и строим идентификатор вида c_A_B_C, где A,B,C-номера сайтов
    }
    return $c
}

# вычисляет некий базовый вектор вдоль указанного ребра в таком направлении, чтобы при наблюдении из сайта он смотрел налево
proc edge_get_direction { state_name edge } {
    upvar 1 $state_name state

    lassign $state([dict get $state($edge) site]) x y
    lassign $state([dict get $state([dict get $state($edge) sibling]) site]) sx sy

    if {[dict exists $state($edge) origin]} {
        # если у границы задан источник, берём его
        lassign [dict get $state([dict get $state($edge) origin]) point] xo yo
    } elseif {[dict exists $state($edge) ex-origin]} {
        lassign [dict get $state([dict get $state($edge) ex-origin]) point] xo yo
    } elseif {[dict exists $state($edge) target]} {
        # если задана конечная точка, то её
        lassign [dict get $state([dict get $state($edge) target]) point] xo yo
    } elseif {[dict exists $state($edge) ex-target]} {
        lassign [dict get $state([dict get $state($edge) ex-target]) point] xo yo
    } else {
        # если ничего не помогает, то точку в середине между сайтами
        set xo [expr {($x+$sx)/2}]
        set yo [expr {($y+$sy)/2}]
    }

    set vx [expr {$sy-$y}]
    set vy [expr {$x-$sx}]
    
    return [list $xo $yo $vx $vy]
}

# не используется
proc get_intersection { x1 y1 dx1 dy1 x2 y2 dx2 dy2 } {
    set delta [expr {$dx2*$dy1-$dx1*$dy2}]
    if {$delta==0} { ;# параллельны
        return 0
    }
    set t1 [expr {(($x1-$x2)*$dy2-($y1-$y2)*$dx2)/$delta}]
    set t2 [expr {(($x1-$x2)*$dy1-($y1-$y2)*$dx1)/$delta}]
    # вообще такой изврат не требуется и x=x1+t1*dx1=x2+t2*dx2, но численная неустойчивость фантастическая. По-хорошему, надо бы выбирать, но пока что усредним
    set x [expr {($x1+$dx1*$t1+$x2+$dx2*$t2)/2}]
    set y [expr {($y1+$dy1*$t1+$y2+$dy2*$t2)/2}]
    return [list $x $y $t1 $t2]
}

# обрезает бесконечные рёбра и замыкает полуоткрытые ячейки на границе диаграммы
proc fix_outer_cells { state_name xmin ymin xmax ymax } {
    upvar 1 $state_name state

    # высчитываем границы, в которые диаграмма помещается целиком
    lassign [list $xmin $ymin $xmax $ymax] lxmin lymin lxmax lymax
    foreach {id vertex} [array get state v*] {
        lassign [dict get $vertex point] x y
        if {$x<$lxmin} {
            set lxmin $x
        } elseif {$x>$lxmax} {
            set lxmax $x
        }
        if {$y<$lymin} {
            set lymin $y
        } elseif {$y>$lymax} {
            set lymax $y
        }
    }

    # Обходим все бесконечные полурёбра, находим их пересечение с границей окна и создаём там вершину
    # Особый случай, когда в диаграмме нет вершин и все пары полурёбер параллельны и бесконечны, также отрабатывает правильно: в список infinite_edges 
    # попадают оба полуребра из пары, для каждого из них создаётся одна вершина, и при этом она становится одному из них концом и второму началом
    # По дороге записываем все сайты, которые засветились на границе
    array set boundary_sites {}
    set vni 0 ;# vertex negative index. Индексы отрицательные, поскольку это не настоящие вершины диаграммы Вороного
    foreach edge $state(infinite_edges) {
        dict with state($edge) { }
        set ssite [dict get $state($sibling) site]
        lassign [edge_get_direction state $edge] xo yo vx vy
        # здесь используется такое окно, что constraint_vector отработает правильно
        lassign [clip_vector $xo $yo $vx $vy $lxmin $lymin $lxmax $lymax] x y which_side
        set vertex "v[incr vni -1]"
        lassign $state($site) sx sy ;# хочется найти расстояние от "вершины" до сайтов
        set r [expr {hypot($x-$sx,$y-$sy)}]
        # такие "вершины" общие только для двух сайтов
        set state($vertex) [dict create point [list $x $y] r $r sites [list $site $ssite] sources $sibling sinks $edge]
        lappend state(V$site) $vertex ;# TODO: сделать нормальную структуру s*
        lappend state(V$ssite) $vertex
        dict set state($edge) target $vertex
        dict set state($sibling) origin $vertex
        set boundary_sites($site) 1
    }
    set state(boundary_sites) [array names boundary_sites]
    
    # Создаём вершины в углах, нужно только разобраться, к каким сайтам они относятся. Заодно составим отдельный список угловых сайтов.
    # Это могут быть только сайты на границе — те, в которых были бесконечные рёбра. Мы предусмотрительно их перечислили в предыдущем цикле.
    foreach x [list $lxmin $lxmin $lxmax $lxmax] y [list $lymin $lymax $lymax $lymin] {
        # TODO: нужно ли проверять, имеется ли уже такая вершина?
#        foreach {k v} [array get state v*] { dict with v {
#            lassign $point vx vy
#            if {$x==$vx&&$y==$vy} continue ;# в этом месте уже есть какая-то вершина
#        } }
        
        # находим ближайший сайт
        set distance inf
        set site {}
        foreach sid $state(boundary_sites) {
            lassign $state($sid) sx sy
            set nd [expr {hypot($sx-$x,$sy-$y)}]
            if {$nd<$distance} {
                set distance $nd
                set site $sid
            }
        }
        set vertex "v[incr vni -1]"
        set state($vertex) [dict create point [list $x $y] r $distance sites $site sources {} sinks {}] ;# рёбра пока не создаём
        lappend state(V$site) $vertex
        lappend corner_sites($site) $vertex ;# одновременно запоминаем, какие сайты в уголках и из их вершин угловые
    }
    
    # Замыкаем ячейки
    # TODO: вообще-то мы с самого начала этой процедуры можем знать, будут ли у нас пограничные сайты с двумя несвязными рёбрами. Может, постобрабатывать отдельно? 
    set eni 0 ;# edge negative index. Индексы отрицательные, поскольку это не настоящие рёбра диаграммы Вороного
    foreach sid $state(boundary_sites) {
        if {[info exists corner_sites($sid)]} { ;# сайт угловой, может быть одна, две, три висящих вершины, , и не хватать двух, трёх или четырёх
            # Общий aлгоритм: отсортировать вершины против часовой стрелки TODO: здесь будет проблема с совпадающими вершинами, а такое случается
            # эту проблему можно попробовать решить более умной сортировкой, которая либо учитывает значения next-prev в рёбрах, либо сортирует не просто вершины,
            # но связные упорядоченные блоки вершин
            set ox 0.0
            set oy 0.0
            set n 0
            foreach v $state(V$sid) {
                lassign [dict get $state($v) point] x y
                set ox [expr {$x+$ox}]
                set oy [expr {$y+$oy}]
                incr n
            }
            set ox [expr {$ox/$n}]
            set oy [expr {$oy/$n}] ;# центр масс
            set ang {}
            foreach v $state(V$sid) {
                lassign [dict get $state($v) point] x y
                lappend ang [list [expr {atan2($y-$oy,$x-$ox)}] $v]
            }
            set ang [lsort -real -decreasing -index 0 $ang]

            # Создаём такой же список, который "прокручен" на один элемент. В цикле будем выбирать одновременно 
            # по одному элементу каждого списка и таким образом переберём все последовательные пары.
            set a2 [lrange $ang 1 end] 
            lappend a2 [lindex $ang 0]
            
            # Подготовка: проходим по рёбрам и создаём список вершина -> ребро, которое в ней начинается и принадлежит сайту sid
            array unset s_sources
            foreach e $state(E$sid) { set s_sources([dict get $state($e) origin]) $e }

            # Между каждой последовательной парой вершин должно быть ребро. Проходим по вершинам и создаём те рёбра, которых не хватает
            set prev ""
            set first ""
            foreach vx1 $ang vx2 $a2 {
                set v1 [lindex $vx1 1]
                set v2 [lindex $vx2 1]
                if {[info exists s_sources($v1)]} { ;# такое ребро уже существует
                    set e $s_sources($v1) 
                } else { ;# такого ребра ещё нет
                    set e "e[incr eni -1]"
                    set state($e) [dict create site $sid origin $v1 target $v2]
                    lappend state(E$sid) $e
                    dict lappend state($v1) sources $e
                    dict lappend state($v2) sinks $e
                }
                # Связывание. Некоторые уже имеющиеся связи мы возможно повторим, но лучше так, чем недосвязать.
                if {$prev==""} { 
                    set first $e 
                } else {
                    dict set state($e) prev $prev
                    dict set state($prev) next $e
                }
                set prev $e
            }
            # Замыкаем контур. После цикла first соедержит самое первое полуребро, а prev — самое последнее, и они тоже должны быть связаны.
            dict set state($prev) next $first
            dict set state($first) prev $prev
        } else { ;# сайт просто пограничный, может либо не хватать одного ребра, либо быть два несвязных ребра и двух не хватать
            if {2==[llength $state(E$sid)]} {
                lassign $state(E$sid) e1 e2
                if {![dict exists $state($e1) next]&&![dict exists $state($e1) next]} {
                    # два ребра, двух не хватает
                    set e1o [dict get $state($e1) origin]
                    set e1t [dict get $state($e1) target]
                    set e2o [dict get $state($e2) origin]
                    set e2t [dict get $state($e2) target]
                    set e3 "e[incr eni -1]"
                    set e4 "e[incr eni -1]"
                    set state($e3) [dict create site $sid origin $e1t target $e2o next $e2 prev $e1]
                    set state($e4) [dict create site $sid origin $e2t target $e1o next $e1 prev $e2]
                    dict_mset state($e1) next $e3 prev $e4
                    dict_mset state($e2) next $e4 prev $e3
                    lappend state(E$sid) $e3
                    lappend state(E$sid) $e4
                    dict lappend state($e1t) sources $e3
                    dict lappend state($e1o) sinks $e4
                    dict lappend state($e2t) sources $e4
                    dict lappend state($e2o) sinks $e3
                } else {
                    # два ребра, но связаны друг с другом — простейший случай цепочки рёбер, в которой одного не хватает
                    # код из общего варианта ниже тоже сработал бы, но в данном случае так быстрее
                    if {[dict exists $state($e1) next]} {
                        set eA $e1
                        set eB $e2
                    } else {
                        set eA $e2
                        set eB $e1
                    }
                    # разрыв после eB
                    set v1 [dict get $state($eA) origin]
                    set v2 [dict get $state($eB) target]
                    set eC "e[incr eni -1]"
                    set state($eC) [dict create site $sid origin $v2 target $v1 next $eA prev $eB]
                    dict set state($eA) prev $eC
                    dict set state($eB) next $eC
                    lappend state(E$sid) $eC
                    dict lappend state($v2) sources $eC
                    dict lappend state($v1) sinks $eC
                }
            } else {
                # не два ребра, это значит, там цепочка рёбер, в которой не хватает одного
                # берём любое ребро сайта
                set eA [lindex $state(E$sid) 0]
                # проходим по prev до начала цепочки
                while {[dict exists $state($eA) prev]} { set eA [dict get $state($eA) prev] }
                # берём любое ребро сайта
                set eB [lindex $state(E$sid) 0]
                # проходим по next до конца цепочки
                while {[dict exists $state($eB) next]} { set eB [dict get $state($eB) next] }
                # разрыв после eB
                set v1 [dict get $state($eA) origin]
                set v2 [dict get $state($eB) target]
                set eC "e[incr eni -1]"
                set state($eC) [dict create site $sid origin $v2 target $v1 next $eA prev $eB]
                dict set state($eA) prev $eC
                dict set state($eB) next $eC
                lappend state(E$sid) $eC
                dict lappend state($v2) sources $eC
                dict lappend state($v1) sinks $eC
            }
        }
    }
}

# Рассчитывает диаграмму Вороного для набора точек points и обрезает бесконечные рёбра и ячейки по указанному окну
proc compute_voronoi_diagram { points xmin ymin xmax ymax } {
    # стр. 157
    # Очередь с приоритетами
    priority_queue events
    
    #
    nextid new_arc a ;# дуги береговой линии
    nextid new_breakpoint b ;# точки излома береговой линии
    nextid new_site s ;# сайты
    nextid new_edge e ;# полурёбра
    nextid new_vertex v ;# вершины

    array set state [list infinite_edges {}] ;# здесь соберутся бесконечные границы, торчащие вертикально вверх (чтобы потом их не отыскивать)

    # 1. Инициализируем очередь событиями типа "сайт" — входные точки
    foreach p $points {
        lassign $p x y
        # костыль для того, чтобы все числа сделать вещественными
        set x [expr {1.0*$x}]
        set y [expr {1.0*$y}]
        set p [list $x $y]
        set site [new_site]
        set state($site) $p
        events add $y "site" $site
    }
    
    # 2. Пока есть события,
    while {[events length]>0} { 
        # 3. Выбираем событие с наименьшей координатой y (наибольшим приоритетом)
        set evt_data [lassign [events get] evt_prio evt_type]
        # 4. Если это событие "сайт", 5. Обрабатываем как сайт, иначе 6. Обрабатываем как окружность
        handle_${evt_type}_event state $evt_data
    }

    # 7.
    array unset state a*
    # извлекаем все бесконечные рёбра из оставшихся точек излома и дополняем список бесконечных границ
    foreach {k v} [array get state b*] {
        lappend state(infinite_edges) [dict get $v edge]
    }
    array unset state b*
    # 8.
    fix_outer_cells state $xmin $ymin $xmax $ymax
    
    # TODO: в структуре ячеек сортировать вершины и рёбра
    return [dict create {*}[array get state v*] {*}[array get state s*] {*}[array get state e*] {*}[array get state V*] {*}[array get state E*]]
}

} ;# namespace eval Fortunes
