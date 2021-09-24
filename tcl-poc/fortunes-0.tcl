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

# если к дуге arc привязано событие окружность, то удаляем его и помечаем событие, как невалидное
proc check_invalidate_circle { state_name arc } {
    upvar 1 $state_name state

    if {[dict exists $state($arc) circle]} {
        puts "    событие окружность [r][dict get $state($arc) circle][n] ($state([dict get $state($arc) circle])) - ложная тревога"
        set state([dict get $state($arc) circle]) 0
    }
    
    # освобождаем дугу от события
    dict unset state($arc) circle
}

# находит дугу, находящуюся над точкой x, когда заметающая линия находится в положении y
proc find_arc_above { state_name x y } {
    upvar 1 $state_name state

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
    return $item
}

# обновляет словарь первого уровня значениями из списка args в формате k1 v1 k2 v2 ...
proc dict_mset { dict_name args } {
    upvar 1 $dict_name mydict
    
    foreach {k v} $args {
        dict set mydict $k $v
    }
}

# обрабатывает событие "сайт", расположенный в точке x y
proc handle_site_event { state_name site } {
    upvar 1 $state_name state
    
    lassign $state($site) x y
    puts "Сайт: [c]$site[n] ($x, $y)"
    
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
    set item [find_arc_above state $x $y]
    
    # Сайт, порождающий эту дугу
    set split_site [dict get $state($item) site]
    # Положение дуги в дереве
    set parent [dict get $state($item) parent]
    set subpath [dict get $state($item) path]
    puts "    [b]$item[n] => $state($item) - дуга над сайтом [b]$split_site[n]; она является потомком [y]$parent[n] в положении \"[y]$subpath[n]\""

    # Если к этой дуге было привязано событие circle — помечаем его как "ложную тревогу"
    check_invalidate_circle state $item

    # 3. Заменяем найденный объект поддеревом из двух или трёх дуг
    set arcs_to_check {} ;# сюда положим дуги, которые могут вызвать событие окружность (проверим в п. 5)

    # Собираем новое поддерево взамен убираемого листика
    if {$y==[lindex $state($split_site) 1]} { ;# если новый сайт и разделяемый лежат на одной высоте, то у нас получится две дуги, а не три
        puts "    сайты лежат на одной высоте; по горизонтали: новый [y]$x[n], старый [y][lindex $state($split_site) 0][n]"
        set narc [new_arc]
        set redge [new_edge]
        set state($narc) [dict create site $site parent $redge]
        set state($redge) [dict create parent $parent path $subpath]
        dict set state($item) parent $redge
        if {$x>[lindex $state($split_site) 0]} { ;# Новая дуга справа
            if {[dict exists $state($item) right]} {
                # Если у старой дуги справа был сосед, 
                set neigh [dict get $state($item) right]
                # теперь это сосед справа для новой дуги,
                dict set state($narc) right $neigh
                # а его сосед слева, соответственно, новая дуга
                dict set state($neigh) left $narc
            }
            # Сосед item слева, если он есть — остаётся как был
            # Соседство: narc - сосед item справа, item - сосед narc слева 
            dict_mset state($item) right $narc path left
            dict_mset state($narc) left $item path right
            dict_mset state($redge) breakpoint [list $split_site $site] left $item right $narc
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
            # Сосед item справа, если он есть — остаётся как был
            # Соседство: narc - сосед item слева, item - сосед narc справа 
            dict_mset state($item) left $narc path right
            dict_mset state($narc) right $item path left
            dict_mset state($redge) breakpoint [list $site $split_site] left $narc right $item
            set _info "слева новая дуга [c]$narc[n] над сайтом [c]$site[n], справа старая дуга [b]$item[n] над сайтом [b]$split_site[n]"
        }
        puts "Граница [c]$redge[n] ($state($redge)): $_info"
        lappend arcs_to_check $item
        lappend arcs_to_check $narc
    } else {
        # Строим структуру из трёх дуг, боковые — кусочки старой дуги, цетральная — новая дуга
        # левый кусочек — оставляем идентификатор от старой дуги item
        set carc [new_arc]
        set rarc [new_arc]
        set ledge [new_edge]
        set redge [new_edge]
        set state($carc) [dict create site $site left $item right $rarc parent $ledge path right] ;# средний кусочек — дуга от нового сайта
        puts "    новая дуга [c]$carc[n] разбивает [b]$item[n] на две части"
        set state($ledge) [dict create breakpoint [list $split_site $site] left $item right $carc  parent $redge path left]
        puts "Левая граница [c]$ledge[n] ($state($ledge)): слева старая дуга [b]${item}[n] над сайтом [b]$split_site[n], справа новая дуга [c]${carc}[n] над сайтом [c]$site[n]"
        set state($rarc) [dict create site $split_site left $carc parent $redge path right] ;# правый кусочек — "копия" левого
        set state($redge) [dict create breakpoint [list $site $split_site] left $ledge right $rarc parent $parent path $subpath]
        puts "Правая граница [c]$redge[n] ($state($redge)): слева поддерево [m]${ledge}[n] и сайт [c]$site[n], справа копия старой дуги [c]${rarc}[n] над сайтом [b]$split_site[n]"
        # Обновляем соседей
        if {[dict exists $state($item) right]} {
            # если у старой дуги был сосед справа,
            set neigh [dict get $state($item) right]
            # это теперь сосед справа её клона,
            dict set state($rarc) right $neigh
            # а его сосед слева, соответственно, теперь клон
            dict set state($neigh) left $rarc
        }
        # Левый сосед item, если есть, остаётся без изменений
        dict_mset state($item) right $carc parent $ledge path left

        # средняя дуга (от нового сайта) пока никак не может "схлопнуться" — она сейчас растёт, по бокам у неё кусочки одной и той же параболы
        lappend arcs_to_check $item
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
    foreach arc $arcs_to_check {
        check_add_circle state $arc $y
    }
    
}

# Проверяет тройку дуг с указанной дугой в середине на предмет схлопывания и добавляет событие "окружность"
proc check_add_circle { state_name carc y } {
    upvar 1 $state_name state

    if {!([dict exists $state($carc) left]&&[dict exists $state($carc) right])} {
        # эта дуга расположена на краю береговой линии
        puts "[y]$carc[n] расположено с краю, не может схлопнуться"
        return 0
    }
    
    # Дуги слева и справа
    set larc [dict get $state($carc) left]
    set rarc [dict get $state($carc) right]
    
    # Точки разрыва слева и справа
    set lbp [find_nearest_common_ancestor state $larc $carc]
    set rbp [find_nearest_common_ancestor state $carc $rarc]
    
    puts "Проверяем структуру [y]$larc[n]-[m]$lbp[n]-[y]$carc[n]-[m]$rbp[n]-[y]$rarc[n]"

    set lsite [dict get $state($larc) site]
    set csite [dict get $state($carc) site]
    set rsite [dict get $state($rarc) site]
    
    lassign $state($lsite) xl yl
    lassign $state($csite) xc yc
    lassign $state($rsite) xr yr

    # Проверяем движение точек разрыва: если не сближаются - событие не создаём
    if {$yr==$yc} {
        if {$yl==$yc} { ;# yl==yc==yl
            set Xp 0
        } else { ;# yl!=yc==yr, точки расположены так: '.. (удаляются) или .'' (сближаются)
            set Xp [expr {($yl>$yc)?-1:1}]
        }
    } else { ;# yr!=yc
        if {$yl==$yc} { ;# yr!=yc==yl, точки расположены так: ..' (удаляются) или .'' (сближаются)
            set Xp [expr {($yr>$yc)?-1:1}]
        } else {
            set Xp [expr {($xr-$xc)/($yr-$yc)-($xl-$xc)/($yl-$yc)}] ;# скорость увеличения расстояния между точками разрыва lbp и rbp
        }
    }
    if {$Xp>=0} {
        puts "   [r]X'[n] = $Xp [r]≥ 0[n] — точки $lbp и $rbp не сближаются, $yl $yc $yr"
        return 0
    }
    
    puts "   [g]X'[n] = $Xp [g]< 0[n] — точки $lbp и $rbp сближаются"

    set c [find_circle {*}[dict get $state($lsite)] {*}[dict get $state($csite)] {*}[dict get $state($rsite)]]
    if {$c==0} {
        puts "    окружность, содержащая сайты [m]$lsite[n] ([dict get $state($lsite)]), [m]$csite[n] [dict get $state($csite)], [m]$rsite[n] ([dict get $state($rsite)]), не существует"
        return 0
    }
    lassign $c cx cy r

    # TODO костыль, чтобы избежать повторного добавления той же самой окружности — ищем окружность с такими же координатами
    foreach {k v} [array get state c*] {
        lassign $v _x _y _r _a
        if {($cx==$_x)&&($cy==$_y)&&($r==$_r)} {
            puts "    [R]($cx $cy; $r) Такую окружность мы уже обрабатывали — [y]$k ($_a)[n][R]![n]"
            return 0
        }
    }
    

    puts "    окружность, содержащая сайты [m]$lsite[n] ([dict get $state($lsite)]), [m]$csite[n] [dict get $state($csite)], [m]$rsite[n] ([dict get $state($rsite)]): ([y]$cx $cy $r[n])"
    # Если нижняя точка окружности выше текущего события, вообще не паримся
    if {$cy+$r<$y} {
        puts "    нижняя точка окружности [expr {$cy+$r}] лежит выше текущего события $y"
        return 0
    }

    # Приоритетом события "окружность" будет её нижняя точка, а остальную информацию добавим на всякий случай
    set circle [new_circle]
    set state($circle) [list $cx $cy $r $carc]
    events add [expr {$cy+$r}] "circle" $circle
    
    dict set state($сarc) circle $circle
    puts "    дуга [y]$carc[n] ($state($carc)) может слопнуться в событии \[[expr {$cy+$r}]\] [c]$circle[n] ($state($circle))"

    return $circle
}

# вычисляет уровень вложенности (расстояние до корня дерева) объекта item
proc find_level { state_name item } {
    upvar 1 $state_name state
    set level 0
    set cur $item
    while {$cur!="T"} {
        set cur [dict get $state($cur) parent]
        incr level
    }
    return $level
}

# находит ближайшего общего предка объектов l и r
proc find_nearest_common_ancestor { state_name l r } {
    upvar 1 $state_name state
    set ldiff [expr [find_level state $l]-[find_level state $r]]
    # спускаемся с длинной ветки до одинаковой глубины
    set _l $l
    set _r $r
    if {$ldiff>0} {
        for {set i 0} {$i<$ldiff} {incr i} {
            set _l [dict get $state($_l) parent]
        }
    } else {
        for {set i $ldiff} {$i<0} {incr i} {
            set _r [dict get $state($_r) parent]
        }
    }
    # теперь спускаемся по обеим веткам до тех пор, пока не встретимся
    while {$_l!=$_r} {
        set _l [dict get $state($_l) parent]
        set _r [dict get $state($_r) parent]
    }
    return $_l
}

# обрабатывает событие "окружность"
proc handle_circle_event { state_name circle } {
    upvar 1 $state_name state
    if {$state($circle)==0} {
        puts "Окружность [r]$circle[n] — событие отменено"
        return
    }
    lassign $state($circle) x y r arc
    puts "Окружность: [m]$circle[n] ($x $y; $r) - [y]$arc[n])"
    set larc [dict get $state($arc) left]
    set rarc [dict get $state($arc) right]
    set parent [dict get $state($arc) parent]
    set subpath [dict get $state($arc) path]
    if {$subpath=="left"} { set sibpath "right" } else { set sibpath "left" }
    set parparent [dict get $state($parent) parent]
    set parsubpath [dict get $state($parent) path]
    if {$parsubpath=="left"} { set parsibpath "right" } else { set parsibpath "left" }
    set sibling [dict get $state($parent) $sibpath]
    puts "    схлопнулась дуга: [r]$arc[n] ($state($arc)) (потомок [b]$parent.[dict get $state($arc) path][n]))"
    puts "    также удаляется узел: [r]$parent[n] ($state($parent))"
    puts "    связи в старом дереве:"
    puts "                [y]$parparent[n] -($parsibpath)→ [g][dict get $state($parparent) $parsibpath][n]"
    puts "                ↑ ↓($parsubpath)"
    puts "                [r]$parent[n] -($sibpath)→ [g]$sibling[n]"
    puts "                ↑ ↓($subpath)"
    if {[dict exists $state($larc) left]} { set _leftmostarc "[g][dict get $state($larc) left][n] = " } else { set _leftmostarc "      " }
    if {[dict exists $state($rarc) right]} { set _rightmostarc " = [g][dict get $state($rarc) right][n]" } else { set _rightmostarc "" }
    puts "    $_leftmostarc[g]$larc[n] = [r]$arc[n] = [g]$rarc[n]$_rightmostarc"

    # 1. Удаляем схлопнувшуюся дугу и всё, что с ней связано
    
    # 1.1 удаляем из береговой линии
    dict set state($larc) right $rarc
    dict set state($rarc) left $larc
    # 1.2 удаляем из дерева
    dict set state($parparent) $parsubpath $sibling 
    dict_mset state($sibling) parent $parparent path $parsubpath
    # 1.3 обновляем точки разрыва
    # находим общего предка новых "соседних" дуг и устанавливаем их сайты в качестве точки разрыва этого предка
    set nca [find_nearest_common_ancestor state $larc $rarc]
    set lsite [dict get $state($larc) site]
    set rsite [dict get $state($rarc) site]
    puts "    Ближайший общий предок $larc ($lsite) и $rarc ($rsite): [y]$nca[n] ($state($nca))"
    dict set state($nca) breakpoint [list $lsite $rsite]
    
    # 1.4 Удаляем все события окружность, которые включали удалённую дугу
    check_invalidate_circle state $larc
    check_invalidate_circle state $rarc
    
    # 2. TODO добавить вершину и полурёбра
    set vertex [new_vertex]
    set state($vertex) [list x $x y $y site [dict get $state($arc) site]]
    
    # 3. Новые тройки добавляем как события окружность TODO: это работает неправильно :(
    check_add_circle state $larc [expr {$y+$r}]
    check_add_circle state $rarc [expr {$y+$r}]
}

# распечатывает береговую линию
proc print_beachline { state_name } {
    upvar 1 $state_name state
    
    # поиск самой левой дуги
    set item $state(T)
    while {![dict exists $state($item) site]} {
        ;# спускаемся по "разрывам", пока не дойдём до "дуги"
        set item [dict get $state($item) left]
    }
    # сборка "береговой линии"
    set s ""
    while {[dict exists $state($item) right]} {
        set site [dict get $state($item) site]
#        set s "$s[m]$item[n] ([b]$site[n]: [dict get $state($site)]) - "
        set s "$s[m]$item[n] ([b]$site[n]) - "
        set item [dict get $state($item) right]
    }
    set site [dict get $state($item) site]
#    set s "$s[m]$item[n] ([b]$site[n]: [dict get $state($site)])"
    set s "$s[m]$item[n] ([b]$site[n])"
    
    puts "Береговая линия: $s"
}

# Рассчитывает диаграмму Вороного для набора точек points
proc compute_voronoi_diagram { points } {
    # стр. 157
    # Очередь с приоритетами
    priority_queue events
    
    #
    nextid new_arc a
    nextid new_site s
    nextid new_edge e
    nextid new_circle c
    
    #
    nextid new_vertex v
    nextid new_halfedge h
    nextid new_cell c

    # 1. Инициализируем очередь событиями типа "сайт" — входные точки
    foreach p $points {
        lassign $p x y
        set site [new_site]
        set state($site) $p
        events add $y "site" $site
    }
    
    # 2. Пока есть события,
    while {[events length]>0} { 
        # 3. Выбираем событие с наибольшей координатой y (приоритетом)
        set evt_data [lassign [events get] evt_prio evt_type]
        puts "[G]$evt_prio: [y]$evt_type[n][G] $evt_data[n]"
        # 4. Если это событие "сайт", 5. Обрабатываем как сайт, иначе 6. Обрабатываем как окружность
        handle_${evt_type}_event state $evt_data
        
        print_beachline state
    }

    puts [array get state]
    # 7.
    # 8.
    set vertices {}
    set vsites {}
    foreach {k v} [array get state v*] {
        lappend vertices [list [dict get $v x] [dict get $v y]]
        lappend vsites [list [dict get $v x] [dict get $v y] {*}$state([dict get $v site])]
    }

    return [list vertices $vertices vsites $vsites]
}

set points {{4.0 2.0} {5.0 5.0} {3.0 9.0} {8.0 2.0}}

set V [compute_voronoi_diagram $points]
puts "[C]Диаграмма Вороного:[n] $V"

# Визуализация
package require Tk
grid [canvas .cnv -width $width -height $height]

set P_r 2
set V_r 2
set scale 30

foreach p [dict get $V vsites] {
    lassign $p x y sx sy
    .cnv create line [expr {$x*$scale}] [expr {$y*$scale}] [expr {$sx*$scale}] [expr {$sy*$scale}] -fill #000 -width 1 -activewidth 2 -tags line
}

foreach p $points {
    lassign $p x y
    .cnv create oval [expr {$x*$scale-$P_r}] [expr {$y*$scale-$P_r}] [expr {$x*$scale+$P_r}] [expr {$y*$scale+$P_r}] -outline #000 -fill #000 -width 1 -activeoutline #0F0 -activewidth 2 -tags point
}
foreach p [dict get $V vertices] {
    lassign $p x y
    .cnv create oval [expr {$x*$scale-$V_r}] [expr {$y*$scale-$V_r}] [expr {$x*$scale+$V_r}] [expr {$y*$scale+$V_r}] -outline #00F -fill #00F -width 1 -activeoutline #0FF -activewidth 2 -tags vertex
}
