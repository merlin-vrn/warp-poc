# Вспомогательные функции

# Объявляет функцию sqr для expr, использовать так: [expr {sqr(выражение)}]
proc ::tcl::mathfunc::sqr {x} { expr {$x*$x} }

# обновляет словарь первого уровня значениями из списка args в формате k1 v1 k2 v2 ...
proc dict_mset { dict_name args } {
    upvar 1 $dict_name mydict
    
    foreach {k v} $args {
        dict set mydict $k $v
    }
}

# Вычисление координат окружности (центр и радиус), проходящей через три заданных точки; возвращает 0 если такая окружность не существует (точки коллинеарны)
proc find_circle { x1 y1 x2 y2 x3 y3 } {
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
    set Dx [expr {($r1*($y2-$y3)+$r2*($y3-$y1)+$r3*($y1-$y2))/2}]
    set Dy [expr {($r1*($x2-$x3)+$r2*($x3-$x1)+$r3*($x1-$x2))/2}]
    set Dr [expr {$r1*($x2*$y3-$x3*$y2)+$r2*($x3*$y1-$x1*$y3)+$r3*($x1*$y2-$x2*$y1)}]
    set x [expr {$Dx*$_D}]
    set y [expr {-$Dy*$_D}]
    set r [expr {sqrt($x*$x+$y*$y+$Dr*$_D)}]
    return [list $x $y $r]
}

# Если построить луч из точки (xo, yo) вдоль вектора (xd, yd), он пересечёт прямоугольник-границу, заданную xmin, ymin, xmax, ymax,
# в некоторой точке. Функция возвращает координаты этой точки. Не проверяется, находится ли точка (xo, yo) внутри прямоугольника.
# Если (xo, yo) находится вне прямоугольника, может возникнуть неопределённое поведение (некорректный результат, исключение).
proc constraint_vector { xo yo xd yd xmin ymin xmax ymax } {
    if {$xd!=0} {
        set t [expr {($xmin-$xo)/$xd}]
        if {$t>=0} {
            set x $xmin
        } else {
            set t [expr {($xmax-$xo)/$xd}]
            set x $xmax
        }
        set y [expr {$t*$yd+$yo}]
#        puts [format "X test: t=%g, x=%g, y=%g" $t $x $y]
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
#        puts [format "Y test: t=%g, x=%g, y=%g" $ty [expr {$ty*$xd+$xo}] $yy]
        if {$ty<$t} {
            set t $ty
            set y $yy
            set x [expr {$t*$xd+$xo}]
#            puts "Y wins"
        } else {
#            puts "X wins"
        }
    }
#    puts "t=$t x=$x y=$y"
    return [list $x $y]
}

# генератор последовательности

# использование: [nextid name prefix] создаёт команду [name]
# эта команда возвращает последовательно значения "prefix0", "prefix1", и. т. д., при каждом очередном вызове
# если prefix не задан, он равен name
proc nextid_coroutine { prefix } { yield ; for {set i 0} {true} {incr i} { yield "$prefix$i"} }

# обёртка для coroutine-команды
proc nextid { name { prefix "" } } { if {$prefix==""} { set prefix $name } ; coroutine $name nextid_coroutine $prefix }


# очередь с приоритетами

# использование очереди: [priority_queue name] создаёт команду [name] (и служебную [name_coroutine])
# добавить элементы: [name add prio ...], причём prio - считается частью элемента
# извлечь первый элемент: [name get]
# подсмотреть первый элемент (не удаляя): [name peek]
# вытащить всю очередь: [name dump]
# узнать длину очереди: [name length]

proc priority_queue_coroutine { } {
    set queue {} ;# переменная контекста корутины, в которой будет храниться собственно очередь
    set prev {} ;# сюда будет передаваться результат выполнения команды и выдаваться yield на следующем цикле
    while {true} {
        set data [yield $prev] ;# yield вернёт то, что мы передали корутине в аргументе
        set data [lassign $data cmd] ;# первый элемент попадёт в cmd, остальные (если есть) в data
        switch $cmd {
            "add" {
                set nprio [lindex $data 0] ;# приоритет элемента - в первом аргументе
                # бинарный поиск позиции в очереди, в которую помещать этот элемент
                set min -1
                set max [llength $queue]
                while {$min+1<$max} {
                    set mid [expr {($min+$max)/2}]
                    if {[lindex $queue $mid 0]>$nprio} { ;# сложный lindex: выбираем элемент 0 элемента mid из queue
                        set max $mid
                    } else {
                        set min $mid
                    }
                }
                set queue [linsert $queue $max $data]
                set prev {} ;# у этой команды пустой ответ
            }
            "get" { set queue [lassign $queue prev] }
            "peek" { set prev [lindex $queue 0] }
            "dump" { set prev $queue }
            "length" { set prev [llength $queue] }
        }
    }
}

# обёртка для создания инстанса coroutine и для coroutine-команды
proc priority_queue { name } {
    set coro ${name}_coroutine
    coroutine $coro priority_queue_coroutine
    proc $name { args } "$coro \$args"
}
