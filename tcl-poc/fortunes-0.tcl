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
    while {![dict exists $state($item) site]} { ;# у дуги всегда есть свойство — порождающий сайт, а у точки излома нет такого свойства
        lassign [dict get $state($item) breakpoint] lsite rsite ;# это ссылки соответственно на дугу "слева" и "справа" от точки излома
        lassign [dict get $state($lsite)] xl yl
        lassign [dict get $state($rsite)] xr yr
        puts [format "    [y]$item[n] => $state($item) - точка излома между дуг сайта [y]$lsite[n] (%g, %g) и сайта [y]$rsite[n] (%g, %g)" $xl $yl $xr $yr]
        if {$yr!=$yl} {
            # в уравнении два корня, если поменять порядок точек - корни меняются местами. Здесь нужен со знаком "-" перед sqrt (TODO: почему именно этот)
            set xlr [expr {($xr*($y-$yl)-$xl*($y-$yr)-hypot($xl-$xr,$yl-$yr)*sqrt(($y-$yl)*($y-$yr)))/($yr-$yl)}] ;# точка пересечения парабол
        } else {
            set xlr [expr {($xl+$xr)/2}] ;# если они находятся на одной высоте, это "вертикальное бесконечное" ребро
        }
        set subpath [expr {($x<$xlr)?"left":"right"}]
        set item [dict get $state($item) $subpath]
        puts [format "    точка излома: [m]%g[n], сайт: [c]%g[n] — переход [y]$subpath[n] к [m]$item[n]" $xlr $x]
    }
    return $item
}

# обрабатывает событие "сайт", расположенный в точке x y
proc handle_site_event { state_name site } {
    upvar 1 $state_name state
    
    lassign $state($site) x y
    puts [format "Сайт: [c]%s[n] (%g, %g)" $site $x $y] 
    
    # 1. Если дерево T отсутствует, инициализируем его объектом "дуга", связанным с этим сайтом site. И выходим
    if {![info exists state(T)]} {
        set arc [new_arc]
        set state($arc) [dict create site $site parent T path {}]
        puts "Новая дуга: [c]$arc[n] ($site)"
        set state(T) $arc
        puts "    инициализируем дерево: T => $state(T)"
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
    puts "    [b]$split_arc[n] ($state($split_arc)) - дуга над сайтом [b]$split_site[n] ($state($split_site)); она является потомком [y]$parent[n] в положении \"[y]$subpath[n]\""

    # Если к этой дуге было привязано событие circle — помечаем его как "ложную тревогу"
    check_invalidate_circle state $split_arc

    # 3. Заменяем найденный объект поддеревом из двух или трёх дуг
    set arcs_to_check {} ;# накопитель для дуг, которые мы будем проверять на "схлопывание" в событии окружность (п. 5)

    # Собираем новое поддерево взамен убираемого листика
    if {$y==$sy} { ;# если новый сайт и разделяемый лежат на одной высоте, то у нас получится две дуги, а не три
        # Это может произойти только в самом начале, пока мы проходим по сайтам с самой малой координатой y и она у них всех совпадает
        # В любом другом случае над сайтом, совпадающем с другим по высоте, всегда найдётся для разбиения дуга, порождённая каким-то из сайтов с ординатой меньше.
        puts [format "    сайты лежат на одной высоте; по горизонтали: новый [y]%g[n], старый [y]%g[n]" $x $sx]
        set narc [new_arc]
        set rbp [new_breakpoint]
        set state($narc) [dict create site $site parent $rbp]
        set state($rbp) [dict create parent $parent path $subpath estart [list [expr {($x+$sx)/2}] -Inf] edir [list 0 Inf]]
        # TODO: Здесь должно быть два полуребра, но точка излома одна.
        dict set state($split_arc) parent $rbp
        if {$x>[lindex $state($split_site) 0]} { ;# Новая дуга справа
            if {[dict exists $state($split_arc) right]} { ;# Если у старой дуги был сосед справа, 
                set neigh [dict get $state($split_arc) right] 
                dict set state($narc) right $neigh ;# теперь это сосед справа для новой дуги,
                dict set state($neigh) left $narc ;# а его сосед слева, соответственно, новая дуга
            }
            # Соседство: narc - сосед split_arc справа, split_arc - сосед narc слева 
            dict_mset state($split_arc) right $narc path left
            dict_mset state($narc) left $split_arc path right
            dict_mset state($rbp) breakpoint [list $split_site $site] left $split_arc right $narc
            set _info "слева старая дуга [b]$split_arc[n] ([b]$split_site[n]), справа новая дуга [c]$narc[n] ([c]$site[n])"
        } else { ;# Новая дуга слева
            if {[dict exists $state($split_arc) left]} { ;# Если у старой дуги слева был сосед, 
                set neigh [dict get $state($split_arc) left]
                dict set state($narc) left $neigh ;# теперь это сосед слева для новой дуги,
                dict set state($neigh) right $narc ;# а его сосед справа, соответственно, новая дуга
            }
            # Соседство: narc - сосед split_arc слева, split_arc - сосед narc справа 
            dict_mset state($split_arc) left $narc path right
            dict_mset state($narc) right $split_arc path left
            dict_mset state($rbp) breakpoint [list $site $split_site] left $narc right $split_arc
            set _info "слева новая дуга [c]$narc[n] ([c]$site[n]), справа старая дуга [b]$split_arc[n] ([b]$split_site[n])"
        }
        puts "Точка излома [c]$rbp[n] ($state($rbp)): $_info"
        lappend arcs_to_check $split_arc
        lappend arcs_to_check $narc
    } else {
        # Строим структуру из трёх дуг, боковые — кусочки старой дуги, цетральная — новая дуга, левый кусочек — оставляем структуру от разбиваемой дуги split_arc
        set carc [new_arc]
        set rarc [new_arc]
        set lbp [new_breakpoint]
        set rbp [new_breakpoint]

        # Координаты нового полуребра: точка начала x, py, вектор направления vx, vy (левое), -vx, -vy (правое)
        set vx [expr {$sy-$y}]
        set vy [expr {$x-$sx}]
        set py [expr {$vy*$vy/(2.0*$vx)+($sy+$y)/2.0}] ;# Точка на параболе над новым сайтом: y=(x-sx)²/(2(sy-y))+(sy+y)/2

        set state($carc) [dict create site $site left $split_arc right $rarc parent $lbp path right] ;# средний кусочек — дуга от нового сайта
        puts [format "    новая дуга [c]$carc[n] разбивает [b]$split_arc[n] на две части в точке %g, %g" $x $py]
        set state($lbp) [dict create breakpoint [list $split_site $site] left $split_arc right $carc  parent $rbp path left estart [list $x $py] edir [list $vx $vy]]
        puts "Леавя точка излома [c]$lbp[n] ($state($lbp)): слева старая дуга [b]$split_arc[n] ([b]$split_site[n]), справа новая дуга [c]$carc[n] ([c]$site[n])"
        set state($rarc) [dict create site $split_site left $carc parent $rbp path right] ;# правый кусочек — "копия" левого
        set state($rbp) [dict create breakpoint [list $site $split_site] left $lbp right $rarc parent $parent path $subpath estart [list $x $py] edir [list [expr {-$vx}]  [expr {-$vy}]]]
        puts "Правая точка излома [c]$rbp[n] ($state($rbp)): слева поддерево [m]$lbp[n] (сайт [c]$site[n]), справа копия старой дуги [c]$rarc[n] ([b]$split_site[n])"
        # Обновляем соседей
        if {[dict exists $state($split_arc) right]} { ;# если у разбиваемой дуги был сосед справа,
            set neigh [dict get $state($split_arc) right]
            dict set state($rarc) right $neigh ;# это теперь сосед справа её клона,
            dict set state($neigh) left $rarc ;# а его сосед слева, соответственно, теперь клон
        }
        dict_mset state($split_arc) right $carc parent $lbp path left ;# правый сосед разбиваемой дуги теперь новая дуга carc
        lappend arcs_to_check $split_arc
        lappend arcs_to_check $rarc
    }
    
    # Вставляем его в новую позицию
    if {$subpath=={}} {
        puts "    вставляем в корень дерева [m]T[n]"
        set state($parent) $rbp
    } else {
        puts "    вставляем в [g]$parent[n] ($state($parent)) в положение \"[m]$subpath[n]\""
        dict set state($parent) $subpath $rbp
    }
    
    # TODO балансировка дерева
    
    # TODO 4. Создаём в выходной структуре полурёбра
    
    # 5. Проверяем две вновь возникшие тройки соседних дуг на предмет слопывания средней. Добавляем для таких событие "окружность"
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
    
    # Точки излома слева и справа
    set lbp [find_nearest_common_ancestor state $larc $carc]
    set rbp [find_nearest_common_ancestor state $carc $rarc]
    
    puts "Проверяем структуру [y]$larc[n]-[m]$lbp[n]-[y]$carc[n]-[m]$rbp[n]-[y]$rarc[n]"

    set lsite [dict get $state($larc) site]
    set csite [dict get $state($carc) site]
    set rsite [dict get $state($rarc) site]
    
    lassign $state($lsite) xl yl
    lassign $state($csite) xc yc
    lassign $state($rsite) xr yr
    
    # Координаты полурёбер
    lassign [dict get $state($lbp) estart] xsl ysl ;# Left half-edge Start x, y
    lassign [dict get $state($lbp) edir] xdl ydl ;# Left half-edge Direction x, y
    lassign [dict get $state($rbp) estart] xsr ysr
    lassign [dict get $state($rbp) edir] xdr ydr
    puts [format "    Координаты полурёбер: [m]$lbp[n]: (%g, %g) → (%g, %g); [m]$rbp[n]: (%g, %g) → (%g, %g)" $xsl $ysl $xdl $ydl $xsr $ysr $xdr $ydr]
    if {$ydl==Inf} { ;# левое полуребро — бесконечное вертикальное
        if {(($xsl-$xsr)>0) || ($xdr>=0)} {
            puts "    левое полуребро [r]$lbp[n] вертикальное бесконечное, а правое [r]$rbp[n] с ним не пересекается — параллельно или направлено в другую сторону"
            return 0
        }
        set cx $xsl
        set cy [expr {$ysr+($xsl-$xsr)*$ydr/$xdr}]
        puts "    полурёбра [g]$lbp[n] и [g]$rbp[n] пересекаются"
    } else { ;# левое полуребро не бесконечное вертикальное
        if {$ydr==Inf} { ;# правое ребро бесконечное вертикальное
            if {(($xsl-$xsr)>0) || ($xdl<=0)} { ;# ($xsr-$xsl)*$xdl<=0
                puts "    правое полуребро [r]$rbp[n] вертикальное бесконечное, а левое [r]$lbp[n] направлено в другую сторону"
                return 0
            }
            set cx $xsr
            set cy [expr {$ysl+($xsr-$xsl)*$ydl/$xdl}]
            puts "    полурёбра [g]$lbp[n] и [g]$rbp[n] пересекаются"
        } else {
            puts [format "    [y]x[n] = %g + [y]tl[n] %g = %g + [y]tr[n] %g" $xsl $xdl $xsr $xdr]
            puts [format "    [y]y[n] = %g + [y]tl[n] %g = %g + [y]tr[n] %g" $ysl $ydl $ysr $ydr]
            set D [expr {$ydl*$xdr-$xdl*$ydr}]
            if {$D==0} {
                puts "    полурёбра [r]$lbp[n] и [r]$rbp[n] не пересекаются — параллельны"
                return 0
            }
            set tl [expr {(($ysr-$ysl)*$xdr-($xsr-$xsl)*$ydr)/$D}]
            set tr [expr {(($ysr-$ysl)*$xdl-($xsr-$xsl)*$ydl)/$D}]
            # Если параметры tl и tr оба неотрицательны, полурёбра движутся к пересечению
            if {$tl<0} {
                puts [format "    [r]tl[n] = [m]%g[n] < 0 - полуребро [r]$lbp[n] растёт в направлении, противоположном точке пересечения прямых" $tl]
                return 0
            }
            if {$tr<0} {
                puts [format "    [r]tr[n] = [m]%g[n] < 0 - полуребро [r]$rbp[n] растёт в направлении, противоположном точке пересечения прямых" $tr]
                return 0
            }
            set cx [expr {$xsl+$tl*$xdl}]
            set cy [expr {$ysl+$tl*$ydl}]
            puts [format "    [c]tl[n] = [m]%g[n] ≥ 0, [c]tr[n] = [m]%g[n] ≥ 0 — полурёбра [g]$lbp[n] и [g]$rbp[n] пересекаются" $tl $tr]
        }
    }

    set r [expr {hypot($xc-$cx, $yc-$cy)}]
    puts [format "    в точке [c]x[n] = [m]%g[n], [c]y[n] = [m]%g[n] на расстоянии [c]r[n] = [m]%g[n] от узлов [m]$lsite[n], [m]$csite[n], [m]$rsite[n]" $cx $cy $r]

    set c [find_circle {*}[dict get $state($lsite)] {*}[dict get $state($csite)] {*}[dict get $state($rsite)]]
    if {$c==0} {
        puts "    окружность, содержащая сайты [m]$lsite[n] ([dict get $state($lsite)]), [m]$csite[n] [dict get $state($csite)], [m]$rsite[n] ([dict get $state($rsite)]), не существует"
        return 0
    }
    lassign $c cx1 cy1 r1
    if {$cx1!=$cx||$cy1!=$cy||$r!=$r1} {
        puts "    [R]Пересечение ($cx, $cy, $r) не совпадает с окружностью [y]($cx1, $cy1, $r1)[n][R]![n]"
    }

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
    
    dict set state($carc) circle $circle
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
    # 1.3 обновляем точки излома
    # и нужно указать новое направление полуребра!
    # находим общего предка новых "соседних" дуг и устанавливаем их сайты в качестве точки излома этого предка
    set nca [find_nearest_common_ancestor state $larc $rarc]
    set lsite [dict get $state($larc) site]
    set rsite [dict get $state($rarc) site]
    lassign $state($lsite) xl yl
    lassign $state($rsite) xr yr
    set vx [expr {$yl-$yr}]
    set vy [expr {$xr-$xl}]
    dict_mset state($nca) breakpoint [list $lsite $rsite] estart [list $x $y] edir [list $vx $vy]
    
    puts "    Обновленная точка излома между [b]$larc[n] ($lsite) и [b]$rarc[n] ($rsite): [c]$nca[n] ($state($nca))"

    # 1.4 Удаляем все события окружность, которые включали удалённую дугу
    check_invalidate_circle state $larc
    check_invalidate_circle state $rarc
    
    # 2. TODO добавить вершину и полурёбра
    
    # вершина имеет отношение к трём сайтам, которые определяют эту окружность
    set csite [dict get $state($arc) site]
    
    set vertex [new_vertex]
    set state($vertex) [list x $x y $y sites [list $lsite $csite $rsite]]
    
    # на этой вершине заканчиваются несколько рёбер
    # рёбра разделяют каждую пару сайтов; мы тут знаем только один конец ребра
    set he_cr [new_halfedge]
    set he_lc [new_halfedge]
    set he_rl [new_halfedge]
    set state($he_cr) [list lsite $csite rsite $rsite vertex $vertex]
    set state($he_lc) [list lsite $lsite rsite $csite vertex $vertex]
    set state($he_rl) [list lsite $rsite rsite $lsite vertex $vertex]
    
    # 3. Новые тройки добавляем как события окружность TODO: это работает неправильно :(
    check_add_circle state $larc [expr {$y+$r}]
    check_add_circle state $rarc [expr {$y+$r}]
}

# распечатывает береговую линию
proc print_beachline { state_name } {
    upvar 1 $state_name state
    
    # поиск самой левой дуги
    set item $state(T)
    # спускаемся по "точкам излома", пока не дойдём до "дуги"
    while {![dict exists $state($item) site]} {
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
    nextid new_breakpoint b
    nextid new_site s
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
        puts [format "[G]%g: [y]$evt_type[n][G] $evt_data[n]" $evt_prio]
        # 4. Если это событие "сайт", 5. Обрабатываем как сайт, иначе 6. Обрабатываем как окружность
        handle_${evt_type}_event state $evt_data
        
        print_beachline state
    }

    #puts [array get state]
    # 7.
    # 8.
    array set half_edges {}
    array set full_edges {}
    foreach {k v} [array get state h*] {
        puts "Полуребро [y]$k[n] $v"
        dict with v {
            set my_sid "$lsite.$rsite" ;# индекс этого ребра
            set tw_sid "$rsite.$lsite" ;# индекс его двойника
            if {[info exists half_edges($my_sid)]} {
                puts "    [R]такое полуребро уже было - $half_edges($my_sid)![n]"
                continue
            }
            set half_edges($my_sid) [list id $k {*}$v]
            if {[info exists half_edges($tw_sid)]} {
                set twin [dict get $half_edges($tw_sid) id]
                set tver [dict get $half_edges($tw_sid) vertex]
                puts "    нашлась вторая половина полуребра: [g]$twin[n] $half_edges($tw_sid)"
                dict_mset half_edges($my_sid) twin $twin end $tver
                dict_mset half_edges($tw_sid) twin $k end $vertex
                set full_edges(f[incr i]) [list $lsite $rsite $vertex $tver]
            }
        }
    }
    
    return [dict create {*}[array get state v*] {*}[array get state s*] {*}[array get full_edges]]
}

#set points {{4.0 2.0} {5.0 5.0} {3.0 9.0} {8.0 2.0} {7.0 6.0}}
set points {{0.0 0.0} {2.0 0.0} {4.0 0.0} {1.0 2.0} {3.0 2.0} {2.0 4.0} {3.0 6.0} {4.0 4.0} {5.0 2.0} {6.0 0.0}}
#set points $points2

set V [compute_voronoi_diagram $points]
puts "[C]Диаграмма Вороного:[n] $V"

# Визуализация
package require Tk
grid [canvas .cnv -width $width -height $height]
set tv_sts ""
grid [label .sts -textvariable tv_sts]
.cnv bind clicktoinfo <ButtonPress-1> clicktoinfo

set S_r 3
set S_style {-outline #000 -fill #000 -width 1 -activeoutline #F00 -activefill #F00 -activewidth 2 -tags {point clicktoinfo}}
set V_r 2
set V_style {-outline #00F -fill #00F -width 1 -activeoutline #F0F -activefill #F0F -activewidth 2 -tags {vertex clicktoinfo}}
set L_style {-fill #0FF -activefill #FF0 -width 1 -activewidth 2 -tags {line}}
set E_style {-fill #00F -activefill #F0F -width 1 -activewidth 2 -tags {edge}}
set D_style {-fill #000 -activefill #F00 -width 1 -activewidth 2 -tags {triangulation}}
#set scale 1
#set scale 4
#set scale 30
set scale 60

dict for {k v} $V {
    switch -glob $k {
        v* { dict with v {
            foreach site $sites {
                lassign [dict get $V $site] sx sy
                #.cnv create line [expr {$x*$scale}] [expr {$y*$scale}] [expr {$sx*$scale}] [expr {$sy*$scale}] {*}$L_style
            }
            set cnv_ids([.cnv create oval [expr {$x*$scale-$V_r}] [expr {$y*$scale-$V_r}] [expr {$x*$scale+$V_r}] [expr {$y*$scale+$V_r}] {*}$V_style]) $k
        } }
        s* { 
            lassign $v sx sy
            set cnv_ids([.cnv create oval [expr {$sx*$scale-$S_r}] [expr {$sy*$scale-$S_r}] [expr {$sx*$scale+$S_r}] [expr {$sy*$scale+$S_r}] {*}$S_style]) $k
        }
        f* {
            lassign $v sl sr vs ve
            set vs [dict get $V $vs]
            set ve [dict get $V $ve]
            lassign [dict get $V $sl] sx1 sy1
            lassign [dict get $V $sr] sx2 sy2
            set x1 [dict get $vs x]
            set y1 [dict get $vs y]
            set x2 [dict get $ve x]
            set y2 [dict get $ve y]
            .cnv create line [expr {$x1*$scale}] [expr {$y1*$scale}] [expr {$x2*$scale}] [expr {$y2*$scale}] {*}$E_style
            .cnv create line [expr {$sx1*$scale}] [expr {$sy1*$scale}] [expr {$sx2*$scale}] [expr {$sy2*$scale}] {*}$D_style
        }
    }
}

proc clicktoinfo { } {
    global V cnv_ids tv_sts
    # определяем, по какому элементу canvas кликнули, а потом по массиву cnv_ids преобразуем в элемент диаграммы Вороного
    set cnv_id [.cnv find withtag current]
    set tv_sts "$cnv_ids($cnv_id) [dict get $V $cnv_ids($cnv_id)]"
    puts "[m]$cnv_ids($cnv_id)[n] [dict get $V $cnv_ids($cnv_id)]"
}
