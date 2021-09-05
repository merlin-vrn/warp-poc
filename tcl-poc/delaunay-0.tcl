#!/usr/bin/env tclsh
#package require Tk

# adding new point: build a Delaunay triangulation

set width 640
set height 480

set points1 {
    { 92  91}
    {546  92}
    {104 396}
    {529 381}
    {246 353}
    {273 353}
    {368 353}
    {399 353}
    {275 265}
    {316 264}
    {275 242}
    {344 230}
    {342 171}
    {275 164}
    {355 198}
    {342 257}
}

set points2 {
    {0 0}
    {2 0}
    {4 0}
    {1 2}
    {3 2}
    {2 4}
    {3 6}
    {4 4}
    {5 2}
    {6 0}
}

# вычисляет, является ли pi лексикографически большей, чем pj
proc lexigraphically_larger { pi pj } {
    lassign $pi xi yi
    lassign $pj xj yj
    # согласно определению на стр. 204: pi ">" pj, если yi>yj либо yi=yj и xi>xj
    if {$yi>$yj} {
        return 1
    }
    if {$yi==$yj} {
        if {$xi>$xj} {
            return 1
        }
    }
    return 0
}

# выясняет, лежит ли точка pr слева от направленного отрезка pi pj
proc is_to_the_left { tau_name pr pi pj } {
    # хочется обрабатывать символические точки "по имени", поэтому пусть на вход подаются их индексы, а не "координаты", и поэтому нам нужна структура tau
    upvar 1 $tau_name tau
    # сначала обработаем "символические" точки (стр. 204)
    if {$pj=="p-1"} {
        # прямая в сторону "нижней" точки — пробная должна быть "больше"
        return [lexigraphically_larger $tau($pr) $tau($pi)]
    }
    if {$pj=="p-2"} {
        # прямая в сторону "верхней" точки — пробная должна быть "меньше"
        return [lexigraphically_larger $tau($pi) $tau($pr)]
    }
    if {$pi=="p-1"} {
        # прямая из "нижней" точки — пробная должна быть "меньше"
        return [lexigraphically_larger $tau($pj) $tau($pr)]
    }
    if {$pi=="p-2"} {
        # прямая из "верхней" точки — пробная должна быть "больше"
        return [lexigraphically_larger $tau($pr) $tau($pj)]
    }
    # если ни одна из точек pi, pj не является символической — распаковываем координаты и используем простую линейную алгебру
    lassign $tau($pi) xi yi
    lassign $tau($pr) xr yr
    lassign $tau($pj) xj yj
    if {($xj-$xi)*($yr-$yi)>($xr-$xi)*($yj-$yi)} {
        return 1
        # равенство означало бы точку, принадлежащую прямой
    }
    return 0
}

# выясняет, принадлежит ли точка ребру (границе некоторого треугольника) TODO: возможно, стоит объединить с is_to_the_left, т.к. логика очень сходная
proc is_on_the_edge { tau_name pr pi pj } {
    # хочется обрабатывать символические точки "по имени", поэтому пусть на вход подаются их индексы, а не "координаты", и поэтому нам нужна структура tau
    upvar 1 $tau_name tau
    # ни одна точка не может принадлежать "символическому ребру"
    if {$pj=="p-1"} { return 0 }
    if {$pj=="p-2"} { return 0 }
    if {$pi=="p-1"} { return 0 }
    if {$pi=="p-2"} { return 0 }
    # если ни одна из точек pi, pj не является символической — распаковываем координаты и используем простую линейную алгебру
    lassign $tau($pi) xi yi
    lassign $tau($pr) xr yr
    lassign $tau($pj) xj yj
    if {($xj-$xi)*($yr-$yi)==($xr-$xi)*($yj-$yi)} {
        return 1
    }
    return 0
}

# выясняет, принадлежит ли точка pr треугольнику tri (включая границу)
proc belongs_to_triangle { tau_name pr tri } {
    upvar 1 $tau_name tau
    lassign [lindex $tau($tri) 0] pi pj pk
    puts "принадлежность $pr ($tau($pr)) треугольнику $tri: $pi ($tau($pi)), $pj ($tau($pj)), $pk ($tau($pk))"
    if {[is_to_the_left tau $pr $pi $pj]} {
        puts "... $pr ($tau($pr)) левее отрезка $pi ($tau($pi)), $pj ($tau($pj)) — не принадлежит"
        return 0
    }
    if {[is_to_the_left tau $pr $pj $pk]} {
        puts "... $pr ($tau($pr)) левее отрезка $pj ($tau($pj)), $pk ($tau($pk)) — не принадлежит"
        return 0
    }
    if {[is_to_the_left tau $pr $pk $pi]} {
        puts "... $pr ($tau($pr)) левее отрезка $pk ($tau($pk)), $pi ($tau($pi)) — не принадлежит"
        return 0
    }
    # поскольку в is_to_the_left все условия строгие, то мы отсеяли все случаи попадания точек *за* границу треугольника,
    # значит, в оставшемся случае точка находится внутри или на границе треугольника, эти случаи мы различим в функции which_triangle_edge
    puts "... принадлежит"
    return 1
}

# находит в tau треугольник, содержащий точку с индексом pr (координаты с таким индексом уже должны присутствовать в tau)
proc find_triangle { tau_name pr } {
    upvar 1 $tau_name tau
    # начальное значение, далее будем "спускаться" по ссылкам, до тех пор, пока не найдём треугольник-"листик" (без ссылок)
    set tri t0
    while {[lindex $tau($tri) 1]!={}} {
        puts "Треугольник $tri содержит ссылки: [lindex $tau($tri) 1]"
        # проверяем их все
        foreach tri [lindex $tau($tri) 1] {
            if {[belongs_to_triangle tau $pr $tri]} {
                # первый из треугольников, в который попадает наша точка, будет подходящим
                break
            }
        }
    }
    return $tri
}

# выясняет, на какое из рёбер треугольника c индексом tri попала точка (сообщает индексы концов) или же возвращает 0 для внутренней точки
proc which_triangle_edge { tau_name tri pr } {
    upvar 1 $tau_name tau
    # функция вызывается в случае, когда уже установлено, что точка принадлежит треугольнику или его границе, и это "листик"
    puts "какому ребру $tri принадлежит точка $pr?"
    lassign [lindex $tau($tri) 0] pi pj pk
    if {[is_on_the_edge tau $pr $pi $pj]} {
        puts "... $pi $pj"
        return [list $pi $pj]
    }
    if {[is_on_the_edge tau $pr $pj $pk]} {
        puts "... $pj $pk"
        return [list $pj $pk]
    }
    if {[is_on_the_edge tau $pr $pk $pi]} {
        puts "... $pk $pi"
        return [list $pk $pi]
    }
    puts "... внутри треугольника"
    return 0
}

proc is_illegal { tau_name "pipj" } {
    upvar 1 $tau_name tau
    ...
}

proc replace_edge { tau_name "pipj" "prpk" } {
    upvar 1 $tau_name tau
    ...
}

proc legalize_edge { tau_name pr "pipj" } {
    upvar 1 $tau_name tau
    if [is_illegal tau "pipj"] {
        # переворот границы — создаёт треугольники и вешает ссылки! Самая странная операция во всём алгоритме
        replace_edge tau "pipj" "prpk"
        # рекурсивно проверяем на валидность все новосозданные рёбра и исправляем, если требуется
        legalize_edge tau $pr "pipk"
        legalize_edge tau $pr "pkpj"
    }
}

proc find_delaunay { tau_name points } {
    upvar 1 $tau_name tau
    # "1."
    # поиск наибольшего с точки зрения lexigraphically_larger
    set highest_point [lindex $points 0]
    set r 0
    for {set t 0} {$t<[llength $points]} {incr t} {
        if {[lexigraphically_larger [lindex $points $t] $highest_point]} {
            set highest_point [lindex $points $t]
            set r $t
        }
    }
    # удаляем эту точку из набора
    set points [lreplace $points $r $r]
    puts "1. Лексикографически верхняя точка: p0 = $highest_point"
    # "2." не предполагается никаких действий; логика этого пункта заложена в проверках принадлежности и валидности
    # "3."
#    array set tau [list p0 $highest_point p-1 {left bottom} p-2 {right top} t0 {{p0 p-1 p-2} {}}]
    set tau(p0) $highest_point
    set tau(p-1) {left bottom}
    set tau(p-2) {right top}
    # Формат данных о треугольнике: список индексов точек, список индексов "дочерних" треугольников
    # Треугольник создаётся без ссылок (как "листик"); они добавляются при его разбиении или "инвалидации" переворачиванием ребра
    set tau(t0) {{p0 p-1 p-2} {}}
    puts "3. Стартовая структура: [array get tau]"
    # "4." здесь нужно вычислить "случайную перестановку", а это значит, что подойдёт любая перестановка — в том числе, текущая
    # "5."
    # r индексирует точки
    set r 0
    # t индексирует треугольники
    set t 0
    foreach point $points {
        # "6."
        set tau(p[incr r]) $point
        puts "Добавляем точку: p$r = $point"
        # "7."
        # в который из уже существующих треугольников-"листиков" попадает новая точка?
        set tri [find_triangle tau p$r]
        puts "Треугольник $tri, содержащий точку p$r: [lindex $tau($tri) 0]"
        # "8."
        if {[set edge [which_triangle_edge tau $tri p$r]]==0} {
            puts "Точка находится внутри треугольника, разбиваем его на три части"
            # "9."
            # здесь накопятся новые треугольники
            set newtri {}
            lassign [lindex $tau($tri) 0] pi pj pk
            set tau(t[incr t]) [list [list p$r $pi $pj] {}]
            lappend newtri t$t
            puts "Добавляем треугольник t$t = [lindex $tau(t$t) 0]"
            set tau(t[incr t]) [list [list p$r $pj $pk] {}]
            lappend newtri t$t
            puts "Добавляем треугольник t$t = [lindex $tau(t$t) 0]"
            set tau(t[incr t]) [list [list p$r $pk $pi] {}]
            lappend newtri t$t
            puts "Добавляем треугольник t$t = [lindex $tau(t$t) 0]"
            # Теперь нужно заполнить поле со ссылками в треугольнике $tri ссылками на наши новые треугольники
            lset tau($tri) 1 $newtri
            # "10."
            # "11."
            # "12."
        } else {
            # "13."
            # второй случай на рис. 9.7 стр. 200
            puts "Точка находится на границе $edge"
            # находим смежный по этому ребру треугольник
            # "14."
            # "15."
            # "16."
            # "17."
            # "18."
        }
    }
}

find_delaunay delaunay $points2

puts "Результат триангуляции: треугольники"
foreach {idx val} [array get delaunay t*] {
    # нас интересуют только "листики", ...
    if {[lindex $val 1]!={}} { continue }
    lassign [lindex $val 0] pi pj pk
    # ..., не включающие "символических точек" (первая точка треугольника не может оказаться "сивмолической")
    if {$pj=="p-1"} { continue }
    if {$pj=="p-2"} { continue }
    if {$pk=="p-1"} { continue }
    if {$pk=="p-2"} { continue }
    puts "$idx => $delaunay($pi), $delaunay($pj), $delaunay($pk)"
}
