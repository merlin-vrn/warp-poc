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
    # TODO: поддерживать в дугах ссылки на точки излома не только в структуре дерева, но и в структуре "береговой линии"; это поможет избежать поисков общих предков
    if {$y==$sy} { ;# если новый сайт и разделяемый лежат на одной высоте, то у нас получится две дуги, а не три
        # Это может произойти только в самом начале, пока мы проходим по сайтам с самой малой координатой y и она у них всех совпадает
        # В любом другом случае над сайтом, совпадающем с другим по высоте, всегда найдётся для разбиения дуга, порождённая каким-то из сайтов с ординатой меньше.
        puts [format "    сайты лежат на одной высоте; по горизонтали: новый [y]%g[n], старый [y]%g[n]" $x $sx]
        # Создаётся два бесконечных вертикальных полуребра, хотя точка излома одна (правая). С левым полуребром не связывается никакая точка излома.
        set le [new_edge]
        set re [new_edge]
        set narc [new_arc]
        set rbp [new_breakpoint]
        set state($narc) [dict create site $site parent $rbp]
        # точка излома ассоциируется с границей, связаной с правым сайтом
        set state($rbp) [dict create parent $parent path $subpath estart [list [expr {($x+$sx)/2}] -Inf] edir [list 0 Inf] edge $re]
        set state($le) [dict create sibling $re point [list [expr {($x+$sx)/2}] Inf] direction [list 0 -Inf]] ;# новые полурёбра являются двойниками друг друга
        set state($re) [dict create sibling $le point [list [expr {($x+$sx)/2}] -Inf] direction [list 0 Inf]] ;# про их координаты почти ничего неизвестно :(
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
            # Направления полурёбер выбираются такими, чтобы они обходили сайт против часовой стрелки. Т.е. если смотреть на полуребро из сайта, оно смотрит налево.
            dict_mset state($le) site $split_site
            dict_mset state($re) site $site 
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
            # Направления полурёбер выбираются такими, чтобы они обходили сайт против часовой стрелки. Т.е. если смотреть на полуребро из сайта, оно смотрит налево.
            dict_mset state($le) site $site 
            dict_mset state($re) site $split_site
            set _info "слева новая дуга [c]$narc[n] ([c]$site[n]), справа старая дуга [b]$split_arc[n] ([b]$split_site[n])"
        }
        puts "Точка излома [c]$rbp[n] ($state($rbp)): $_info"
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

        # Координаты новых полурёбер: точка начала x, py, вектор направления vx, vy (смотрит налево), -vx, -vy (смотрит направо)
        set vx [expr {$sy-$y}]
        set vy [expr {$x-$sx}]
        set py [expr {$vy*$vy/(2.0*$vx)+($sy+$y)/2.0}] ;# Точка на параболе над новым сайтом: py=(x-sx)²/(2(sy-y))+(sy+y)/2
        
        # Направления полурёбер выбираются такими, чтобы они обходили сайт против часовой стрелки. Т.е. если смотреть на полуребро из сайта, оно смотрит налево.
        set state($le) [dict create sibling $re point [list $x $py] direction [list $vx $vy] site $site]
        set state($re) [dict create sibling $le point [list $x $py] direction [list [expr {-$vx}] [expr {-$vy}]] site $split_site]

        set state($carc) [dict create site $site left $split_arc right $rarc parent $lbp path right] ;# средний кусочек — дуга от нового сайта
        puts [format "    новая дуга [c]$carc[n] разбивает [b]$split_arc[n] на две части в точке %g, %g" $x $py]
        # точка излома ассоциируется с границей, связаной с правым сайтом, в данном случае с site связан le
        set state($lbp) [dict create breakpoint [list $split_site $site] left $split_arc right $carc  parent $rbp path left estart [list $x $py] edir [list $vx $vy] edge $le]
        puts "Леавя точка излома [c]$lbp[n] ($state($lbp)): слева старая дуга [b]$split_arc[n] ([b]$split_site[n]), справа новая дуга [c]$carc[n] ([c]$site[n])"
        set state($rarc) [dict create site $split_site left $carc parent $rbp path right] ;# правый кусочек — "копия" левого
        # точка излома ассоциируется с границей, связаной с правым сайтом, в данном случае с split_site связан re
        set state($rbp) [dict create breakpoint [list $site $split_site] left $lbp right $rarc parent $parent path $subpath estart [list $x $py] edir [list [expr {-$vx}]  [expr {-$vy}]] edge $re]
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

# Проверяет тройку дуг с указанной дугой в середине на предмет схлопывания и добавляет событие "окружность".
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

    set lsite [dict get $state($larc) site]
    set csite [dict get $state($carc) site]
    set rsite [dict get $state($rarc) site]

    set circle [new_circle $lsite $csite $rsite]
    # проверяем, не было ли уже окружности через эти же сайты в другом порядке
    if {[info exists state($circle)]} {
        puts "    Окружность через сайты $rsite, $csite, $lsite мы уже обрабатывали"
        return 0
    }

    # Точки излома слева и справа

    # parent(carc) и nca(larc,rarc) — это тот же самый набор, что и nca(larc,carc) и nca(carc,rarc), но неизвестно, в каком порядке
    # теоретически, от перестановки левой и правой точки излома вообще ничего не должно измениться
    # TODO: хранить в дугах эту информацию!
    set lbp [find_nearest_common_ancestor state $larc $carc]
    set rbp [find_nearest_common_ancestor state $carc $rarc]
    
    puts "Проверяем структуру [y]$larc[n]-[m]$lbp[n]-[y]$carc[n]-[m]$rbp[n]-[y]$rarc[n]"
    
    lassign $state($lsite) xl yl
    lassign $state($csite) xc yc
    lassign $state($rsite) xr yr
    
    # Координаты полурёбер
    lassign [dict get $state($lbp) estart] xsl ysl ;# Left half-edge Start x, y
    lassign [dict get $state($lbp) edir] xdl ydl ;# Left half-edge Direction x, y
    lassign [dict get $state($rbp) estart] xsr ysr
    lassign [dict get $state($rbp) edir] xdr ydr
    puts [format "    Координаты полурёбер: [m]$lbp[n]: (%g, %g) → (%g, %g); [m]$rbp[n]: (%g, %g) → (%g, %g)" $xsl $ysl $xdl $ydl $xsr $ysr $xdr $ydr]
    
    # TODO: в этой логике где-то всё равно не всё в порядке :(
    if {$ydl==Inf} { ;# левое полуребро — бесконечное вертикальное
        if {(($xsl-$xsr)>0) || ($xdr>=0)} {
            puts "    левое полуребро [r]$lbp[n] вертикальное бесконечное, а правое [r]$rbp[n] с ним не пересекается — параллельно или направлено в другую сторону"
            return 0
        }
# TODO Либо происходит страшная потеря точности, либо срабатывает ошибка где-то в логике
#        set cx $xsl
#        set cy [expr {$ysr+($xsl-$xsr)*$ydr/$xdr}]
        puts "    полурёбра [g]$lbp[n] и [g]$rbp[n] пересекаются"
    } else { ;# левое полуребро не бесконечное вертикальное
        if {$ydr==Inf} { ;# правое ребро бесконечное вертикальное
            if {(($xsl-$xsr)>0) || ($xdl<=0)} { ;# ($xsr-$xsl)*$xdl<=0
                puts "    правое полуребро [r]$rbp[n] вертикальное бесконечное, а левое [r]$lbp[n] направлено в другую сторону"
                return 0
            }
# TODO Либо происходит страшная потеря точности, либо срабатывает ошибка где-то в логике
#            set cx $xsr
#            set cy [expr {$ysl+($xsr-$xsl)*$ydl/$xdl}]
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
# TODO Либо происходит страшная потеря точности, либо срабатывает ошибка где-то в логике
#            set cx [expr {$xsl+$tl*$xdl}]
#            set cy [expr {$ysl+$tl*$ydl}]
            puts [format "    [c]tl[n] = [m]%g[n] ≥ 0, [c]tr[n] = [m]%g[n] ≥ 0 — полурёбра [g]$lbp[n] и [g]$rbp[n] пересекаются" $tl $tr]
        }
    }

# TODO Либо происходит страшная потеря точности, либо срабатывает ошибка где-то в логике
#    set r [expr {hypot($xc-$cx, $yc-$cy)}]
#    if {(abs(hypot($xr-$cx, $yr-$cy)/$r-1)>1e-6)||(abs(hypot($xl-$cx, $yl-$cy)/$r-1)>1e-6)} {
#        puts "    [R]Хьюстон, у нас проблемы: [expr {hypot($xc-$cx, $yc-$cy)}] [expr {hypot($xr-$cx, $yr-$cy)}] [expr {hypot($xl-$cx, $yl-$cy)}][n]"
#        lassign [find_circle $xr $yr $xc $yc $xl $yl] cx cy r
#        puts "    [Y]$r[n] ($cx, $cy)"
#    }
# Поэтому, пока что вычисляем так. Вроде бы лишние вычисления, но вот же.
    lassign [find_circle $xr $yr $xc $yc $xl $yl] cx cy r
    
    puts [format "    в точке [c]x[n] = [m]%g[n], [c]y[n] = [m]%g[n] на расстоянии [c]r[n] = [m]%g[n] от узлов [m]$lsite[n], [m]$csite[n], [m]$rsite[n]" $cx $cy $r]

    # TODO Если нижняя точка окружности выше текущего события, это странно, возможно ли вообще такое?
    if {$cy+$r<$y} {
        puts [format "    [R]нижняя точка окружности $circle %g лежит выше текущего события %g[n]" [expr {$cy+$r}] $y]
        return 0
    }

    # Приоритетом события "окружность" будет её нижняя точка, а остальную информацию добавим на всякий случай
    set state($circle) [list $cx $cy $r $carc]
    events add [expr {$cy+$r}] "circle" $circle
    
    dict set state($carc) circle $circle
    puts [format "    дуга [y]$carc[n] ([y]$csite[n]) может слопнуться в событии [c]$circle[n] (%g, %g; %g) с приоритетом [m]%g[n]" $cx $cy $r [expr {$cy+$r}]]

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
    
    # parent и nca(larc,rarc) — это тот же самый набор, что и nca(larc,arc) и nca(arc,rarc), но неизвестно, в каком порядке
    # TODO: хранить в дугах эту информацию!
    set lbp [find_nearest_common_ancestor state $larc $arc]
    set rbp [find_nearest_common_ancestor state $arc $rarc]
    
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
    # полурёбра, которые соединились в точке, связаны с точками излома parent и nca
    set lsite [dict get $state($larc) site]
    set rsite [dict get $state($rarc) site]
    lassign $state($lsite) xl yl
    lassign $state($rsite) xr yr
    set vx [expr {$yl-$yr}]
    set vy [expr {$xr-$xl}]
    dict_mset state($nca) breakpoint [list $lsite $rsite] estart [list $x $y] edir [list $vx $vy]
    
    # 1.4 Удаляем все события окружность, которые включали удалённую дугу
    check_invalidate_circle state $larc
    check_invalidate_circle state $rarc
    
    # 2. TODO добавить вершину и полурёбра
    
    # вершина имеет отношение к трём сайтам, которые определяют эту окружность
    set csite [dict get $state($arc) site]
    
    set vertex [new_vertex]
    set state($vertex) [list x $x y $y r $r sites [list $lsite $csite $rsite]]

    # эти полурёбра заканчиваются в настоящей вершине
    set l_edge [dict get $state($lbp) edge]
    set r_edge [dict get $state($rbp) edge]
    # эти начинаются
    set l_edge_sibling [dict get $state($l_edge) sibling]
    set r_edge_sibling [dict get $state($r_edge) sibling]
    
    # в этой вершине начинается новое полуребро, к которому привяжем $nca, и заканчивается новый же его двойник
    set le [new_edge]
    set re [new_edge]
    set state($le) [dict create sibling $re site $lsite target $vertex point [list $x $y] direction [list [expr {-$vx}] [expr {-$vy}]] next $l_edge_sibling]
    set state($re) [dict create sibling $le site $rsite origin $vertex point [list $x $y] direction [list $vx $vy] prev $r_edge]

    # привязываем так, чтобы с сайта мы видели обход вдоль рёбер против часовой стрелки, "налево"
    dict set state($nca) edge $re

    puts "    Обновленная точка излома между [b]$larc[n] ($lsite) и [b]$rarc[n] ($rsite): [c]$nca[n] ($state($nca))"
    
    # TODO чисто проверка, убрать
    if {([dict get $state($l_edge) site]!=$csite)||([dict get $state($r_edge_sibling) site]!=$csite)} {
        puts "[R]$l_edge от сайта [dict get $state($l_edge) site], $r_edge_sibling от сайта [dict get $state($r_edge_sibling) site], должно быть $csite[n]"
    }
    if {[dict get $state($l_edge_sibling) site]!=$lsite} {
        puts "[R]$l_edge_sibling от сайта [dict get $state($l_edge_sibling) site], должно быть $lsite[n]"
    }
    if {[dict get $state($r_edge) site]!=$rsite} {
        puts "[R]$r_edge от сайта [dict get $state($r_edge) site], должно быть $rsite[n]"
    }
    
    # эти два старых полуребра в настоящей вершине замкнулись друг на друга
    dict_mset state($l_edge) target $vertex next $r_edge_sibling
    dict_mset state($r_edge_sibling) origin $vertex prev $l_edge
    
    # эти два старых полуребра замкнулись на новые полурёбра
    dict_mset state($r_edge) target $vertex next $re
    dict_mset state($l_edge_sibling) origin $vertex prev $le
    
    # запишем в вершину, какие полурёбра в ней начинаются и какие заканчиваются, в том же порядке, что и сайты
    dict_mset state($vertex) sources [list $l_edge_sibling $r_edge_sibling $re] sinks [list $le $l_edge $r_edge]

    # parent больше не точка излома, избавляемся от неё
    unset state($parent)
    
    # и дуга arc больше не существует, схлопнулась
    unset state($arc)
    
    # событие окружность сработало, чтобы не мозолило глаза, избавляемся. Возможно, полезно сохранить оттуда радиус в объекте vertex
    set state($circle) 0
    
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
        set s "$s[m]$item[n] ([b]$site[n]) - "
        set item [dict get $state($item) right]
    }
    set site [dict get $state($item) site]
    set s "$s[m]$item[n] ([b]$site[n])"
    
    puts "Береговая линия: $s"
}

proc new_circle {args} {
    set c "c"
    foreach s [lsort -dictionary $args] {
        set c "${c}_[string range $s 1 end]" ;# отрезаем префикс "s" и строим идентификатор вида c_A_B_C, где A,B,C-номера сайтов
    }
    return $c
}

# Рассчитывает диаграмму Вороного для набора точек points
proc compute_voronoi_diagram { points } {
    # стр. 157
    # Очередь с приоритетами
    priority_queue events
    
    #
    nextid new_arc a ;# дуги береговой линии
    nextid new_breakpoint b ;# точки излома береговой линии
    nextid new_site s ;# сайты
    nextid new_edge e ;# полурёбра
    nextid new_vertex v ;# вершины

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

    # 7.
    puts "[B]Остались дуги[n]: [array get state a*]"
    puts "[Y]Остались точки излома[n]: [array get state b*]"
    # 8.
    return [dict create {*}[array get state v*] {*}[array get state s*] {*}[array get state e*]]
}

#set points {{4.0 2.0} {5.0 5.0} {3.0 9.0} {8.0 2.0} {7.0 6.0}}
#set points $points2

#set points {{5 0} {0 5} {10 5} {5 10}}
#set points {{1 2} {8 1} {9 8} {2 9}}
#set points {{9 2} {1 8} {2 1} {8 9}}
#set points {{5 0} {0 5} {10 5} {5 10} {1 2} {8 1} {9 8} {2 9} {9 2} {1 8} {2 1} {8 9} {5 5}}

set V [compute_voronoi_diagram $points]
puts "[C]Диаграмма Вороного[n]: $V"

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
set E_style {-fill #00F -activefill #F0F -width 1 -activewidth 2 -tags {edge clicktoinfo}}
set D_style {-fill #FF0 -activefill #F00 -width 1 -activewidth 2 -tags {triangulation}}
set scale 1
#set scale 4
#set scale 30
#set scale 60

dict for {k v} $V {
    switch -glob $k {
        v* { dict with v {
            set cnv_ids([.cnv create oval [expr {$x*$scale-$V_r}] [expr {$y*$scale-$V_r}] [expr {$x*$scale+$V_r}] [expr {$y*$scale+$V_r}] {*}$V_style]) $k
        } }
        s* { 
            lassign $v sx sy
            set cnv_ids([.cnv create oval [expr {$sx*$scale-$S_r}] [expr {$sy*$scale-$S_r}] [expr {$sx*$scale+$S_r}] [expr {$sy*$scale+$S_r}] {*}$S_style]) $k
        }
        e* {
            # все рёбра прорисуются дважды (один раз в каждом направлении)!
            if {![dict exists $v target]||![dict exists $v origin]} {
                puts "[r]$k[n]: $v"
                continue
            }
            set target [dict get $v target]
            set origin [dict get $v origin]
            set xo [dict get $V $origin x]
            set yo [dict get $V $origin y]
            set xt [dict get $V $target x]
            set yt [dict get $V $target y]
            set cnv_ids([.cnv create line [expr {$xo*$scale}] [expr {$yo*$scale}] [expr {$xt*$scale}] [expr {$yt*$scale}] {*}$E_style]) $k
#            .cnv create line [expr {$sx1*$scale}] [expr {$sy1*$scale}] [expr {$sx2*$scale}] [expr {$sy2*$scale}] {*}$D_style
        }
    }
}

proc clicktoinfo { } {
    global V cnv_ids tv_sts
    # определяем, по какому элементу canvas кликнули
    set cnv_id [.cnv find withtag current]
    # по массиву cnv_ids преобразуем в ID элемента диаграммы Вороного
    set id $cnv_ids($cnv_id)

    switch -glob $id {
        v* { dict with V $id {
            set tv_sts [format "$id: вершина (%g, %g) на расстоянии %g от сайтов $sites, начало рёбер $sources, конец рёбер $sinks" $x $y $r]
            puts [format "[m]$id[n]: вершина (%g, %g) на расстоянии %g от сайтов $sites, начало рёбер $sources, конец рёбер $sinks" $x $y $r]
        } }
        s* { 
            lassign [dict get $V $id] sx sy
            set tv_sts [format "$id: сайт (%g, %g)" $sx $sy]
            puts [format "[m]$id[n]: сайт (%g, %g)" $sx $sy]
        }
        e* {
            set sid [dict get $V $id sibling]
            set site [dict get $V $id site]
            set ssite [dict get $V $sid site]
            set v1 [dict get $V $id origin]
            set v2 [dict get $V $id target]
            set tv_sts "$id+$sid: ребро между $site и $ssite, соединяет вершины $v1 и $v2"
            puts "[m]$id+$sid[n]: ребро между $site и $ssite, соединяет вершины $v1 и $v2"
        }
    }
}
