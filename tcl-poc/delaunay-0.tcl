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

proc is_illegal { tau_name "pipj" } {
    upvar 1 $tau_name tau
    ...
}

proc legalize_edge { tau_name pr "pipj" } {
    upvar $tau_name tau # передаём имя массива как аргумент
    if [is_illegal tau "pipj"] {
        replace_edge tau "pipj" "prpk" # this changes tau! # flip edge
        legalize_edge tau $pr "pipk"
        legalize_edge tau $pr "pkpj"
    }
}

# находит в tau треугольник, содержащий точку с индексом pr (координаты с таким индексом уже должны присутствовать в tau)
proc find_triangle { tau_name pr } {
    upvar 1 $tau_name tau
#    ...
    return t0
}

# выясняет, на какую из границ треугольника c индексом tri попала точка (сообщает индексы её концов) или же 0 для внутренней точки
proc which_triangle_edge { tau_name tri pr } {
    upvar 1 $tau_name tau
#    ...
    return 0
}

proc find_delaunay { tau_name points } {
    upvar 1 $tau_name tau
    # "1."
    set highest_point [lindex [lsort -decreasing -real -index 1 [lsort -decreasing -real -index 0 $points]] 0]
    puts "1. Лексикографически верхняя точка: p0 = $highest_point"
    # "2." ???
    # "3."
#    array set tau [list p0 $highest_point p-1 ... p-2 ... T0 {{p0 p-1 p-2} {}}]
    set tau(p0) $highest_point
    set tau(p-1) ...
    set tau(p-2) ...
    # Формат данных о треугольнике: список индексов точек, список индексов "дочерних" треугольников
    # Треугольник создаётся без ссылок, они появляются при его "уничтожении" как треугольника Делоне
    set tau(t0) {{p0 p-1 p-2} {}}
    puts "3. Стартовая структура T: [array get tau]"
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
        set tri [find_triangle tau p$r]
        puts "Треугольник, содержащий точку p$r: $tri = [array get tau $tri]"
        # "8."
        if {[set edge [which_triangle_edge tau $tri p$r]]==0} {
            puts "Точка находится внутри треугольника, разбиваем его на три части"
            # "9."
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
puts [array get delaunay]
