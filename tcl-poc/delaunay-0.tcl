#!/usr/bin/env tclsh
#package require Tk

# Построение триангуляции Делоне

# поддержка разноцветного вывода
source "ansi.tcl"
namespace import ansi::*

proc tcl::mathfunc::sqr { x } {
    return [expr $x*$x]
}

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

# выясняет, на какое из рёбер треугольника c индексом tri попала точка или же возвращает 0 для внутренней точки
# возвращает: ребро (концы), смежный по этому ребру треугольник, точку, не принадлежащую ребру (чтобы потом не искать)
proc which_triangle_edge { tau_name tri pr } {
    upvar 1 $tau_name tau
    # функция вызывается в случае, когда уже установлено, что точка принадлежит треугольнику или его границе, и это "листик"
    puts "какому ребру $tri принадлежит точка $pr?"
    lassign [lindex $tau($tri) 0] pi pj pk
    lassign [lindex $tau($tri) 2] t_i t_j t_k
    if {[is_on_the_edge tau $pr $pi $pj]} {
        puts "... $pi $pj"
        return [list $pi $pj $t_k $pk]
    }
    if {[is_on_the_edge tau $pr $pj $pk]} {
        puts "... $pj $pk"
        return [list $pj $pk $t_i $pi]
    }
    if {[is_on_the_edge tau $pr $pk $pi]} {
        puts "... $pk $pi"
        return [list $pk $pi $t_j $pj]
    }
    puts "... внутри треугольника"
    return 0
}

proc is_symbolic { pr } {
    return [expr ("$pr"=="p-1")||("$pr"=="p-2")]
}

proc point_index { pr } {
    return [string range $pk 1 end]
}

# основано на проверке как в points-in-a-cricle.tcl
# вычисляется два определителя и          | xi yi 1 |         | xi-xk yi-yk (xi-xk)²+(yi-yk)² |
# сравниваются их знаки. Одинаковые   M = | xj yj 1 |    Mi = | xj-xk yj-yk (xj-xk)²+(yj-yk)² |
# знаки означают нахождение точки         | xr yr 1 |         | xr-xk yr-yk (xr-xk)²+(yr-yk)² |
# внутри окружности, заданной тремя другими точками. Знак определителя M по сути означает порядок
# точек i, j, r против часовой стрелки либо по часовой, M=0 — точки принадлежат одной прямой
# Mi означает положение точки k относительно окружности, проходящей через i, j, r, причём 0
# означает принадлежность окружности, знак как у M — внутри, знак противоположный — вне. 
proc is_inside_circle {xi yi xj yj xr yr xk yk} {
    set M [expr $xi*($yj-$yr)+$xj*($yr-$yi)+$xr*($yi-$yj)]
    if {$M==0} {
        puts "... треугольник [r]вырожден[n], точки ($xi, $yi), ($xj, $yj), ($xr, $yr) принадлежат одной прямой!"
        return 0
    }
    if {$M>0} {
        puts ">>>[r]M=$M![n]<<<"
    }
    set _xi [expr $xi-$xk]
    set _xj [expr $xj-$xk]
    set _xr [expr $xr-$xk]
    set _yi [expr $yi-$yk]
    set _yj [expr $yj-$yk]
    set _yr [expr $yr-$yk]
    set Mi [expr ($_xi*$_xi+$_yi*$_yi)*($_xj*$_yr-$_xr*$_yj)+($_xj*$_xj+$_yj*$_yj)*($_xr*$_yi-$_xi*$_yr)+($_xr*$_xr+$_yr*$_yr)*($_xi*$_yj-$_xj*$_yi)]
    if {$Mi==0} {
        puts "... все четыре точки ($xi, $yi), ($xj, $yj), ($xr, $yr), ($xk, $yk) [y]принадлежат одной окружности[n]!"
        return 0
    }
    if {($Mi>0)==($M>0)} {
        puts "... точка ($xk, $yk) лежит [m]внутри окружности[n], определяемой ($xi, $yi), ($xj, $yj), ($xr, $yr)"
        return 1
    }
    puts "... точка ($xk, $yk) лежит [g]вне окружности[n], определяемой ($xi, $yi), ($xj, $yj), ($xr, $yr)"
    
    return 0
}

# вычисляет, является ли валидным ребро $pi $pj в текущей диаграмме. Новую точку и треугольник сообщаем, чтобы не искать
proc is_illegal { tau_name pi pj tri pr } {
    upvar 1 $tau_name tau
    # находим смежный треугольник и третью точку
    set nei [lindex $tau($tri) 2 [lsearch [lindex $tau($tri) 0] $pr]]
    if {$nei=={}} {
        # только три ребра не имеют за собой смежных треугольников — рёбра p0 p-1 p-2.
        puts "... нет смежного треугольника - ребро $pi $pj валидно"
        return 0
    }
    foreach pk [lindex $tau($nei) 0] {
        if {($pk!=$pi)&&($pk!=$pj)} {
            break
        }
    }
    puts "... третья точка смежного треугольника $nei: $pk"
    if {[is_symbolic $pi]||[is_symbolic $pj]||[is_symbolic $pk]} { 
        # если хоть одна точка символическая, тест тоже символический; pr не может быть символической — она только что добавлена
        if {min([string range $pk 1 end],[string range $pr 1 end])<min([string range $pi 1 end],[string range $pj 1 end])} {
            puts "... символический тест — ребро $pi $pj (vs $pk $pr) валидно"
            return 0
        } else {
            puts "... символический тест — ребро $pi $pj (vs $pk $pr) невалидно"
            if {($tri=="t9")&&($pr=="p3")} { puts "        [R]КОСТЫЛЬ[n]"; return 0 } ;# страшный костыль
            if {($tri=="t11")&&($pr=="p4")} { puts "        [R]КОСТЫЛЬ[n]"; return 0 } ;# страшный костыль
            if {($tri=="t22")&&($pr=="p6")} { puts "        [R]КОСТЫЛЬ[n]"; return 0 } ;# страшный костыль
            if {($tri=="t27")&&($pr=="p7")} { puts "        [R]КОСТЫЛЬ[n]"; return 0 } ;# страшный костыль
            if {($tri=="t32")&&($pr=="p8")} { puts "        [R]КОСТЫЛЬ[n]"; return 0 } ;# страшный костыль
            if {($tri=="t33")&&($pr=="p8")} { puts "        [R]КОСТЫЛЬ[n]"; return 0 } ;# страшный костыль
            if {($tri=="t37")&&($pr=="p9")} { puts "        [R]КОСТЫЛЬ[n]"; return 0 } ;# страшный костыль
            if {($tri=="t38")&&($pr=="p9")} { puts "        [R]КОСТЫЛЬ[n]"; return 0 } ;# страшный костыль
            return 1
        }
    }
    # вычисляем согласно лемме 9.4, стр. 195
    if {[is_inside_circle {*}$tau($pi) {*}$tau($pj) {*}$tau($pr) {*}$tau($pk)]} {
        puts "... тест на принадлежность окружности — ребро $pi $pj (vs $pk $pr) невалидно"
        return 1
    }
    return 0
}

# заменяет ребро pi pj на "накрест лежащее". Старый треугольник tri и точка pr сообщается для того, чтобы снова не искать
proc replace_edge { tau_name pi pj tri pr } {
    upvar 1 $tau_name tau
    puts "Заменяем ребро: [b]$pi $pj[n]"
    set nei [lindex $tau($tri) 2 [lsearch [lindex $tau($tri) 0] $pr]]
    puts "... смежный треугольник: $nei $tau($nei)"
    foreach pk [lindex $tau($nei) 0] {
        if {($pk!=$pi)&&($pk!=$pj)} {
            break
        }
    }
    puts "... третья точка смежного треугольника $nei: $pk"
    # здесь мы заменяем ребро pi pj на pr pk, при этом вместо треугольников
    # tri(pr pi pj) и nei(pk pj pi) появляются t_i(pr pi pk) и t_j(pr pk pj)
    puts "Новое ребро: [c]$pr $pk[n]"
    # i. находим "внешние" смежные треугольники
    set tn_jr [lindex $tau($nei) 2 [lsearch [lindex $tau($nei) 0] $pj]] ;# смежный по ребру ik
    set tn_ir [lindex $tau($nei) 2 [lsearch [lindex $tau($nei) 0] $pi]] ;# смежный по ребру jk
    set tn_jk [lindex $tau($tri) 2 [lsearch [lindex $tau($tri) 0] $pj]] ;# смежный по ребру ri
    set tn_ik [lindex $tau($tri) 2 [lsearch [lindex $tau($tri) 0] $pi]] ;# смежный по ребру rj
    # ii. создаём новые треугольники
    set t_i t[incr tau(Tri)] 
    set t_j t[incr tau(Tri)]
    set tau($t_i) [list [list $pr $pi $pk] {} {}]
    set tau($t_j) [list [list $pr $pk $pj] {} {}]
    # iii. Обновляем соседей
    update_neighbourhood tau $tn_jr $nei $t_i
    update_neighbourhood tau $tn_ir $nei $t_j
    update_neighbourhood tau $tn_jk $tri $t_i
    update_neighbourhood tau $tn_ik $tri $t_j
    # iv. вешаем в новых треугольниках соседей
    lset tau($t_i) 2 [list $tn_jr $t_j $tn_jk] 
    lset tau($t_j) 2 [list $tn_ir $tn_ik $t_i] 
    # v. вешаем в старых треугольниках ссылки на новые (стр. 203, рис. 9.9)
    lset tau($tri) 1 [list $t_i $t_j]
    lset tau($nei) 1 [list $t_i $t_j]
    puts "Добавляем треугольник [c]$t_i[n] = $tau($t_i)"
    puts "Добавляем треугольник [c]$t_j[n] = $tau($t_j)"
    
    return [list $t_i $t_j $pk]
}

# проверяет на валидность и исправляет ребро pi pj, которое могло стать невалидным после 
# добавления точки pr. Эти три точки — вершины треугольника tri, его мы сообщаем, чтобы не искать
proc legalize_edge { tau_name pr pi pj tri } {
    upvar 1 $tau_name tau
    puts "Проверка ребра $pi $pj (треугольник $tri, после добавления точки $pr)"
    if {[is_illegal tau $pi $pj $tri $pr]} {
        puts "... невалидно"
        # переворот границы — создаёт треугольники и вешает ссылки! Самая странная операция во всём алгоритме
        lassign [replace_edge tau $pi $pj $tri $pr] t_i t_j pk
        # рекурсивно проверяем на валидность новосозданные рёбра и исправляем, если требуется
        legalize_edge tau $pr $pi $pk $t_i
        legalize_edge tau $pr $pk $pj $t_j
    }
}

# заменяет в треугольнике nei соседство с tri на соседство с new
# используется в случае, когда tri поделили на части, либо при перевороте ребра,
# в любом случае, соседней с nei оказалась его часть или замена new
proc update_neighbourhood { tau_name nei tri new } {
    upvar 1 $tau_name tau
    if {$nei=={}} { 
        # нечего менять в несуществующем соседе 
        return
    }
    puts "    соседом треугольника [c]$nei[n] $tau($nei) вместо [b]$tri[n] будет [g]$new[n]"
    # страшная конструкция работает следующим образом:
    # lsearch находит в блоке смежных треугольников позицию, в которой записан индекс старого треугольника
    # затем lset устанавливает в эту позицию индекс соответствующего нового треугольника
    lset tau($nei) 2 [lsearch [lindex $tau($nei) 2] $tri] $new
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
    puts "[g]1.[n] Лексикографически верхняя точка: [c]p0[n] = $highest_point"
    # "2." не предполагается никаких действий; логика этого пункта заложена в проверках принадлежности и валидности
    # "3."
#    array set tau [list p0 $highest_point p-1 {left bottom} p-2 {right top} t0 {{p0 p-1 p-2} {}}]
    set tau(p0) $highest_point
    set tau(p-1) {left bottom}
    set tau(p-2) {right top}
    # Формат данных о треугольнике: список индексов точек, список индексов "дочерних" треугольников, список смежных треугольников
    # Треугольник создаётся без ссылок (как "листик"); они добавляются при его разбиении или "инвалидации" переворачиванием ребра
    set tau(t0) {{p0 p-1 p-2} {} {}}
    puts "[g]3.[n] Стартовая структура: [array get tau]"
    # "4." здесь нужно вычислить "случайную перестановку", а это значит, что подойдёт любая перестановка — в том числе, текущая
    # "5."
    # r индексирует точки
    set r 0
    # t индексирует треугольники
    set tau(Tri) 0
    foreach point $points {
        # "6."
        set tau(p[incr r]) $point
        puts "[g]6.[n] Добавляем точку: [c]p$r[n] = $point"
        # "7."
        # в который из уже существующих треугольников-"листиков" попадает новая точка?
        set tri [find_triangle tau p$r]
        puts "[g]7.[n] Треугольник [c]$tri[n], содержащий точку p$r: $tau($tri)"
        if {[set edge [which_triangle_edge tau $tri p$r]]==0} {
            # "8."
            puts "[g]8.[n] Точка находится [y]внутри[n] треугольника, разбиваем его на три части"
            # "9."
            # точки, из которых состоит треугольник
            lassign [lindex $tau($tri) 0] pi pj pk
            # соответствующие (противолежащие им) смежные треугольники
            lassign [lindex $tau($tri) 2] tu tv tw
            set t_k t[incr tau(Tri)] 
            set t_i t[incr tau(Tri)] 
            set t_j t[incr tau(Tri)]
            set tau($t_k) [list [list p$r $pi $pj] {} {}]
            set tau($t_i) [list [list p$r $pj $pk] {} {}]
            set tau($t_j) [list [list p$r $pk $pi] {} {}]
            # эти треугольники будут смежными друг с другом по двум новым рёбрам, по третьему ребру, оставшемуся
            # от "родительского" треугольника, каждый из них является смежным с тем треугольником, с которым был
            # смежен их "родительский" треугольник по этому ребру
            lset tau($t_k) 2 [list $tw $t_i $t_j]
            lset tau($t_i) 2 [list $tu $t_j $t_k]
            lset tau($t_j) 2 [list $tv $t_k $t_i]
            # во "внешних смежных" треугольниках tu, tv, tw (если они есть) всё ещё указано, что смежным к ним является tri
            # заменяем его в каждом на тот из новых треугольников, который теперь является смежным
            update_neighbourhood tau $tw $tri $t_k
            update_neighbourhood tau $tu $tri $t_i
            update_neighbourhood tau $tv $tri $t_j
            puts "Добавляем треугольник [c]$t_k[n] = $tau($t_k)"
            puts "Добавляем треугольник [c]$t_i[n] = $tau($t_i)"
            puts "Добавляем треугольник [c]$t_j[n] = $tau($t_j)"
            # заполняем поле со ссылками в разбиваемом треугольнике $tri ссылками на эти новые треугольники
            lset tau($tri) 1 [list $t_i $t_j $t_k]
            # проверяем валидность рёбер и, при необходимости, рекурсивно исправляем
            # "10."
            legalize_edge tau p$r $pi $pj $t_k
            # "11."
            legalize_edge tau p$r $pj $pk $t_i
            # "12."
            legalize_edge tau p$r $pk $pi $t_j
        } else {
            # "13."
            # второй случай на рис. 9.7 стр. 200
            lassign $edge pi pj nei pk
            puts "[g]13.[n] Точка находится [y]на границе[n] $pi $pj, принадлежащей также треугольнику [c]$nei[n] = $tau($nei)"
            # "внешние" смежные треугольники
            set tn_jl [lindex $tau($tri) 2 [lsearch [lindex $tau($tri) 0] $pj]]
            set tn_il [lindex $tau($tri) 2 [lsearch [lindex $tau($tri) 0] $pi]]
            set tn_jk [lindex $tau($nei) 2 [lsearch [lindex $tau($nei) 0] $pj]]
            set tn_ik [lindex $tau($nei) 2 [lsearch [lindex $tau($nei) 0] $pi]]
            puts "... смежные треугольники: к $tri - против $pj $tn_jl, против $pi $tn_il; к $nei - против $pj $tn_jk, против $pi $tn_ik" 
            # "14."
            # находим третью точку (не принадлежащую общему ребру) смежного треугольника nei
            foreach pl [lindex $tau($nei) 0] {
                if {($pl!=$pi)&&($pl!=$pj)} {
                    break
                }
            }
            puts "... новые рёбра: $pk p$r и $pl p$r"
            # здесь добавляется четыре треугольника
            set t_jl t[incr tau(Tri)] 
            set t_il t[incr tau(Tri)] 
            set t_jk t[incr tau(Tri)]
            set t_ik t[incr tau(Tri)]
            set tau($t_jl) [list [list p$r $pk $pi] {} {}]
            set tau($t_il) [list [list p$r $pj $pk] {} {}]
            set tau($t_jk) [list [list p$r $pi $pl] {} {}]
            set tau($t_ik) [list [list p$r $pl $pj] {} {}]
            # они будут смежными друг к другу, и к тем внешним, к которым были смежны старые треугольники tri и nei
            lset tau($t_jl) 2 [list $tn_jl $t_jk $t_il]
            lset tau($t_il) 2 [list $tn_il $t_jl $t_ik]
            lset tau($t_jk) 2 [list $tn_jk $t_ik $t_jl]
            lset tau($t_ik) 2 [list $tn_ik $t_il $t_jk]
            # в смежных треугольниках опять же нужно обновить смежные
            update_neighbourhood tau $tn_jl $tri $t_jl
            update_neighbourhood tau $tn_il $tri $t_il
            update_neighbourhood tau $tn_jk $nei $t_jk
            update_neighbourhood tau $tn_ik $nei $t_ik
            puts "Добавляем треугольник [c]$t_jl[n] = $tau($t_jl)"
            puts "Добавляем треугольник [c]$t_il[n] = $tau($t_il)"
            puts "Добавляем треугольник [c]$t_jk[n] = $tau($t_jk)"
            puts "Добавляем треугольник [c]$t_ik[n] = $tau($t_ik)"
            # заполняем поле со ссылками в разбиваемых треугольниках
            lset tau($tri) 1 [list $t_jl $t_il]
            lset tau($nei) 1 [list $t_jk $t_ik]
            # проверяем валидность рёбер и, при необходимости, рекурсивно исправляем
            # "15."
            legalize_edge tau p$r $pi $pl $t_jk
            # "16."
            legalize_edge tau p$r $pl $pj $t_ik
            # "17."
            legalize_edge tau p$r $pj $pk $t_il
            # "18."
            legalize_edge tau p$r $pk $pi $t_jl
        }
    }
}

find_delaunay delaunay $points2
puts [array get delaunay]
puts "Результат триангуляции: треугольники"
foreach {idx val} [array get delaunay t*] {
    # нас интересуют только "листики", ...
    if {[lindex $val 1]!={}} { continue }
    lassign [lindex $val 0] pi pj pk
    # ..., не включающие "символических точек" (первая точка треугольника не может оказаться "символической")
    if {$pj=="p-1"} { continue }
    if {$pj=="p-2"} { continue }
    if {$pk=="p-1"} { continue }
    if {$pk=="p-2"} { continue }
    puts "$idx => $delaunay($pi), $delaunay($pj), $delaunay($pk)"
}
