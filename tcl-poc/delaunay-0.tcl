#!/usr/bin/env tclsh
#package require Tk

# adding new point: build a Delaunay triangulation

set width 640
set height 480

set points {
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

# вычисляет, является ли pi лексикографически большей, чем pj
proc lexigraphically_larger { tau_name pi pj } {
    upvar 1 $tau_name tau
    lassign $tau($pi) xi yi
    lassign $tau($pj) xj yj
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

# выясняет, лежит ли точка pj слева от направленного отрезка pi pk
proc is_to_the_left { tau_name pj pi pk } {
    upvar 1 $tau_name tau
    # сначала обработаем "символические" точки (стр. 204)
    if {$pk=="p-1"} {
        return [lexigraphically_larger tau $pj $pi]
    }
    if {$pk=="p-2"} {
        return [lexigraphically_larger tau $pi $pj]
    }
    if {$pi=="p-1"} {
        return [lexigraphically_larger tau $pk $pj]
    }
    if {$pi=="p-2"} {
        return [lexigraphically_larger tau $pj $pk]
    }
    # если ни одна из точек pi, pk не является символической — распаковываем координаты и используем простую линейную алгебру
    lassign $tau($pi) xi yi
    lassign $tau($pj) xj yj
    lassign $tau($pk) xk yk
    if {($xk-$xi)*($yj-$yi)>($xj-$xi)*($yk-$yi)} {
        return 1
    }
    return 0
}

# выясняет, принадлежит ли точка pr треугольнику tri
proc is_inside_triangle { tau_name pr tri } {
    upvar 1 $tau_name tau
    lassign [lindex $tau($tri) 0] pi pj pk
    puts "принадлежность $pr ($tau($pr)) треугольнику $pi ($tau($pi)), $pj ($tau($pj)), $pk ($tau($pk))"
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
            if {[is_inside_triangle tau $pr $tri]} {
                # первый из треугольников, в который попадает наша точка, будет подходящим
                break
            }
        }
    }
    return $tri
}

# выясняет, на какую из границ треугольника c индексом tri попала точка (сообщает индексы её концов) или же 0 для внутренней точки
proc which_triangle_edge { tau_name tri pr } {
    upvar 1 $tau_name tau
#    ...
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
    set highest_point [lindex [lsort -decreasing -real -index 1 [lsort -decreasing -real -index 0 $points]] 0]
    puts "1. Лексикографически верхняя точка: p0 = $highest_point"
    # "2." ???
    # "3."
#    array set tau [list p0 $highest_point p-1 ... p-2 ... t0 {{p0 p-1 p-2} {}}]
    set tau(p0) $highest_point
    set tau(p-1) ...
    set tau(p-2) ...
    # Формат данных о треугольнике: список индексов точек, список индексов "дочерних" треугольников
    # Треугольник создаётся без ссылок, они появляются при его "уничтожении" как треугольника Делоне
    set tau(t0) {{p0 p-1 p-2} {}}
    puts "3. Стартовая структура: [array get tau]"
    # "4." ???
    # "5."
    # индексирует точки
    set r 0
    # индексирует треугольники
    set t 0
    foreach point $points {
        if {$point==$highest_point} {
            # эту точку мы обработали первой
            continue
        }
        # "6."
        set tau(p[incr r]) $point
        puts "Добавляем точку: p$r = $point"
        # "7."
        # в который из уже существующих треугольников попадает новая точка?
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
        } else { # "13."
            puts "Точка находится на границе $edge, ..."
            # "14."
            # "15."
            # "16."
            # "17."
            # "18."
        }
    }
}

find_delaunay delaunay $points

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
