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
        set circle [dict get $state($arc) circle]
        if {$state($circle)==0} {
            puts "    [R]событие окружность $circle было отменено ранее[n]"
        } else {
            lassign $state($circle) x y r
            puts [format "    событие окружность [r]$circle[n] (%g, %g; %g) - ложная тревога" $x $y $r]
            set state($circle) 0
        }
        # отвязываем дугу от события
        dict unset state($arc) circle
    }
}

# находит дугу, находящуюся над точкой x, когда заметающая линия находится в положении y
proc find_arc_above { state_name x y } {
    upvar 1 $state_name state

    set item $state(T) ;# начиная с дерева
    while {![dict exists $state($item) site]} { ;# у дуги всегда есть свойство — порождающий сайт, а у точки излома нет такого свойства
        lassign [dict get $state($item) breakpoint] lsite rsite ;# это ссылки соответственно на сайты, порождающие дуги "слева" и "справа" от точки излома
        lassign [dict get $state($lsite)] xl yl
        lassign [dict get $state($rsite)] xr yr
        puts [format "    [y]$item[n] - точка излома между дуг сайта [y]$lsite[n] (%g, %g) и сайта [y]$rsite[n] (%g, %g)" $xl $yl $xr $yr]
        if {$yr!=$yl} {
            # в уравнении два корня, если поменять порядок точек - корни меняются местами. Здесь нужен со знаком "-" перед sqrt (TODO: почему именно этот)
            set xlr [expr {($xr*($y-$yl)-$xl*($y-$yr)-hypot($xl-$xr,$yl-$yr)*sqrt(($y-$yl)*($y-$yr)))/($yr-$yl)}] ;# точка пересечения парабол
        } else {
            set xlr [expr {($xl+$xr)/2}] ;# если фокусы находятся на одной высоте, точка пересечения у парабол тоже одна и она посередине
        }
        set subpath [expr {($x<$xlr)?"left":"right"}]
        set item [dict get $state($item) $subpath]
        puts [format "    точка излома: ([m]%g[n], %g), сайт: ([c]%g[n], %g) — переход [y]$subpath[n] к [m]$item[n]" $xlr $y $x $y]
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
        set vy [expr {abs($x-$sx)}]
        # точка излома ассоциируется с полуребром, связанным с правым сайтом
        set state($rbp) [dict create parent $parent path $subpath edge $re]
        set state($le) [dict create sibling $re point [list [expr {($x+$sx)/2}] Inf] direction [list 0 [expr {-$vy}]]] ;# новые полурёбра являются двойниками друг друга
        set state($re) [dict create sibling $le point [list [expr {($x+$sx)/2}] -Inf] direction [list 0 $vy]] ;# координата y точки начала неизвестна :(
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
            # Направления полурёбер выбираются такими, чтобы они обходили сайт против часовой стрелки. Т.е. если смотреть на полуребро из сайта, оно смотрит налево.
            dict set state($le) site $split_site
            dict set state($re) site $site 
            set _info "слева старая дуга [b]$split_arc[n] ([b]$split_site[n]), справа новая дуга [c]$narc[n] ([c]$site[n])"
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
            # Направления полурёбер выбираются такими, чтобы они обходили сайт против часовой стрелки. Т.е. если смотреть на полуребро из сайта, оно смотрит налево.
            dict set state($le) site $site 
            dict set state($re) site $split_site
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

        set state($carc) [dict create site $site left $split_arc right $rarc parent $lbp path right lbp $lbp rbp $rbp] ;# средний кусочек — дуга от нового сайта
        puts [format "    новая дуга [c]$carc[n] разбивает [b]$split_arc[n] на две части в точке %g, %g" $x $py]
        # точка излома ассоциируется с полуребром, связанным с правым сайтом, в данном случае с site связан le
        set state($lbp) [dict create breakpoint [list $split_site $site] left $split_arc right $carc  parent $rbp path left edge $le]
        puts "Леавя точка излома [c]$lbp[n] ($state($lbp)): слева старая дуга [b]$split_arc[n] ([b]$split_site[n]), справа новая дуга [c]$carc[n] ([c]$site[n])"
        set state($rarc) [dict create site $split_site left $carc parent $rbp path right lbp $rbp] ;# правый кусочек — "копия" левого
        # точка излома ассоциируется с полуребром, связанным с правым сайтом, в данном случае с split_site связан re
        set state($rbp) [dict create breakpoint [list $site $split_site] left $lbp right $rarc parent $parent path $subpath edge $re]
        puts "Правая точка излома [c]$rbp[n] ($state($rbp)): слева поддерево [m]$lbp[n] (сайт [c]$site[n]), справа копия старой дуги [c]$rarc[n] ([b]$split_site[n])"
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
    # проверяем, не было ли уже окружности через эти же сайты, возможно, перечисленные в другом порядке
    if {[info exists state($circle)]} {
        puts "    Окружность через сайты [b]$rsite[n], [b]$csite[n], [b]$lsite[n] мы уже обрабатывали"
        return 0
    }

    # Точки излома слева и справа хранятся в самой дуге
    # parent(carc) и nca(larc,rarc) — это тот же самый набор, что и nca(larc,carc) и nca(carc,rarc), но неизвестно, в каком порядке
    # теоретически, от перестановки левой и правой точки излома вообще ничего не должно измениться
    set lbp [dict get $state($carc) lbp]
    set rbp [dict get $state($carc) rbp]

    # Полурёбра привязаны к точкам излома
    set le [dict get $state($lbp) edge]
    set re [dict get $state($rbp) edge]

    puts "Проверяем структуру [y]$larc[n]($lsite)-[m]$lbp[n]($le)-[y]$carc[n]($csite)-[m]$rbp[n]($re)-[y]$rarc[n]($rsite)"
    
    # Координаты сайтов
    lassign $state($lsite) xl yl
    lassign $state($csite) xc yc
    lassign $state($rsite) xr yr
    
    # Координаты полурёбер
    lassign [dict get $state($le) point] xsl ysl ;# Left half-edge Start x, y
    lassign [dict get $state($le) direction] xdl ydl ;# Left half-edge Direction x, y
    lassign [dict get $state($re) point] xsr ysr
    lassign [dict get $state($re) direction] xdr ydr
    puts [format "    Координаты полурёбер: [m]$le[n]: (%g, %g) → (%g, %g); [m]$re[n]: (%g, %g) → (%g, %g)" $xsl $ysl $xdl $ydl $xsr $ysr $xdr $ydr]
    
    # TODO: в этой логике где-то всё равно не всё в порядке :(
    if {$ysl==-Inf} { ;# левое полуребро — бесконечное вертикальное
        if {(($xsl-$xsr)>0) || ($xdr>=0)} {
            puts "    левое полуребро [r]$le[n] вертикальное бесконечное, а правое [r]$re[n] с ним не пересекается — параллельно или направлено в другую сторону"
            return 0
        }
        puts "    полурёбра [g]$le[n] и [g]$re[n] пересекаются"
    } else { ;# левое полуребро не бесконечное вертикальное
        if {$ysr==-Inf} { ;# правое ребро бесконечное вертикальное
            if {(($xsl-$xsr)>0) || ($xdl<=0)} { ;# ($xsr-$xsl)*$xdl<=0
                puts "    правое полуребро [r]$re[n] вертикальное бесконечное, а левое [r]$le[n] направлено в другую сторону"
                return 0
            }
            puts "    полурёбра [g]$le[n] и [g]$re[n] пересекаются"
        } else {
            puts [format "    [y]x[n] = %g + [y]tl[n] %g = %g + [y]tr[n] %g" $xsl $xdl $xsr $xdr]
            puts [format "    [y]y[n] = %g + [y]tl[n] %g = %g + [y]tr[n] %g" $ysl $ydl $ysr $ydr]
            set D [expr {$ydl*$xdr-$xdl*$ydr}]
            if {$D==0} {
                puts "    полурёбра [r]$le[n] и [r]$re[n] не пересекаются — параллельны"
                return 0
            }
            # TODO нам нужны только знаки этих отношений, а значит, деление можно заменить умножением — так быстрее и шансов словить проблемы меньше
            set tl [expr {(($ysr-$ysl)*$xdr-($xsr-$xsl)*$ydr)/$D}]
            set tr [expr {(($ysr-$ysl)*$xdl-($xsr-$xsl)*$ydl)/$D}]
            # Если параметры tl и tr оба неотрицательны, полурёбра движутся к пересечению
            if {$tl<0} {
                puts [format "    [r]tl[n] = [m]%g[n] < 0 - полуребро [r]$le[n] растёт в направлении, противоположном точке пересечения прямых" $tl]
                return 0
            }
            if {$tr<0} {
                puts [format "    [r]tr[n] = [m]%g[n] < 0 - полуребро [r]$re[n] растёт в направлении, противоположном точке пересечения прямых" $tr]
                return 0
            }
            puts [format "    [c]tl[n] = [m]%g[n] ≥ 0, [c]tr[n] = [m]%g[n] ≥ 0 — полурёбра [g]$le[n] и [g]$re[n] пересекаются" $tl $tr]
        }
    }

    # Если вычислять cx и cy исходя из пересечения прямых, иногда происходит страшная потеря точности, поэтому вычисляем так.
    lassign [find_circle $xr $yr $xc $yc $xl $yl] cx cy r
    
    puts [format "    в точке [c]x[n] = [m]%g[n], [c]y[n] = [m]%g[n] на расстоянии [c]r[n] = [m]%g[n] от узлов [m]$lsite[n], [m]$csite[n], [m]$rsite[n]" $cx $cy $r]

    # TODO Если нижняя точка окружности выше текущего события, это странно, возможно ли вообще такое?
    if {$cy+$r<$y} {
        puts [format "    [R]нижняя точка окружности $circle %g лежит выше текущего события %g[n]" [expr {$cy+$r}] $y]
        return 0
    }

    # Приоритетом события "окружность" будет её нижняя точка
    set state($circle) [list $cx $cy $r $carc]
    events add [expr {$cy+$r}] "circle" $circle
    
    dict set state($carc) circle $circle
    puts [format "    дуга [y]$carc[n] ([y]$csite[n]) может слопнуться в событии [c]$circle[n] (%g, %g; %g) с приоритетом [m]%g[n]" $cx $cy $r [expr {$cy+$r}]]

    return $circle
}

# обрабатывает событие "окружность"
proc handle_circle_event { state_name circle } {
    upvar 1 $state_name state
    if {$state($circle)==0} {
        puts "Окружность [r]$circle[n] — событие отменено"
        return
    }
    lassign $state($circle) x y r carc
    puts "Окружность: [m]$circle[n] ($x $y; $r) - [y]$carc[n])"
    set larc [dict get $state($carc) left]
    set rarc [dict get $state($carc) right]
    set parent [dict get $state($carc) parent]
    set subpath [dict get $state($carc) path]
    if {$subpath=="left"} { set sibpath "right" } else { set sibpath "left" }
    set parparent [dict get $state($parent) parent]
    set parsubpath [dict get $state($parent) path]
    if {$parsubpath=="left"} { set parsibpath "right" } else { set parsibpath "left" }
    set sibling [dict get $state($parent) $sibpath]
    puts "    схлопнулась дуга: [r]$carc[n] ($state($carc)), она была потомком [r]$parent.$subpath[n]"
    puts "    также удаляется узел: [r]$parent[n] ($state($parent)), он был потомком [b]$parparent.$parsubpath[n]"
    puts "    дуга [b]$sibling[n] ($state($sibling)) становится потомком [c]$parparent.$parsubpath[n]"

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

    lassign $state($lsite) xl yl
    lassign $state($rsite) xr yr
    set vx [expr {$yl-$yr}]
    set vy [expr {$xr-$xl}]
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
    # Для каждого из полурёбер, у которых не задан target, находим пересечение с границей окна и создаём там вершину, её и назначаем target.
    # А полуребру-двойнику назначаем эту вершину как origin
    set vni 0 ;# vertex negative index
    foreach {id edge} [array get state e*] {
        if {[dict exists $edge target]} { continue }
        dict with edge {
            set xo [dict get $state($origin) x]
            set yo [dict get $state($origin) y]
            lassign $direction xd yd
#            puts "[y]$e[n] $v"
            if {$xd!=0} {
                set t [expr {($xmin-$xo)/$xd}]
                if {$t>=0} {
                  set x $xmin
                } else {
                    set t [expr {($xmax-$xo)/$xd}]
                    set x $xmax
                }
                set y [expr {$t*$yd+$yo}]
#                puts [format "X test: t=%g, x=%g, y=%g" $t $x $y]
            } else {
                set t Inf
            }
            if {$yd!=0} {
                set ty [expr {($ymin-$yo)/$yd}]
                if {$ty>=0} {
                  set yy $ymin
                } else {
                    set ty [expr {($ymax-$yo)/$yd}]
                    set yy $ymax
                }
#                puts [format "Y test: t=%g, x=%g, y=%g" $ty [expr {$ty*$xd+$xo}] $yy]
                if {$ty<$t} {
                    set t $ty
                    set y $yy
                    set x [expr {$t*$xd+$xo}]
#                    puts "Y wins"
                } else {
#                    puts "X wins"
                }
            }
#            puts "t=$t x=$x y=$y"
        }
        set vertex "v[incr vni -1]"
        # тут будет максимум два сайта
        set state($vertex) [dict create x $x y $y r Inf sites [list $site [dict get $state($sibling) site]] sources $sibling sinks $id]
        dict set state($id) target $vertex
        dict set state($sibling) origin $vertex
    }
    
    return [dict create {*}[array get state v*] {*}[array get state s*] {*}[array get state e*]]
}

#set points {{4.0 2.0} {5.0 5.0} {3.0 9.0} {8.0 2.0} {7.0 6.0}}
#set points $points3

#set points {{5 0} {0 5} {10 5} {5 10}}
#set points {{1 2} {8 1} {9 8} {2 9}}
#set points {{9 2} {1 8} {2 1} {8 9}}
#set points {{5 0} {0 5} {10 5} {5 10} {1 2} {8 1} {9 8} {2 9} {9 2} {1 8} {2 1} {8 9} {5 5}}

# автовычисление масштаба
set p0 [lindex $points 0]
lassign $p0 minx miny
lassign $p0 maxx maxy
unset p0
foreach p $points {
    lassign $p x y
    if {$x>$maxx} { set maxx $x } else { if {$x<$minx} { set minx $x } }
    if {$y>$maxy} { set maxy $y } else { if {$y<$miny} { set miny $y } }
}
set scale [expr {min(($width-1)/$maxx,($height-1)/$maxy)}]
puts [format "Диапазон координат: [y]%g[n]÷[y]%g[n], [y]%g[n]÷[y]%g[n]; устанавливаем масштаб [c]%g[n]" $minx $maxx $miny $maxy $scale]

set V [compute_voronoi_diagram $points 0 0 $maxx $maxy]
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
