proc ::tcl::mathfunc::sqr {x} { expr {$x*$x} }

# генератор последовательности
# использование: [nextid prefix] создаёт команду [prefix]
# эта команда возвращает последовательно значения "prefix0", "prefix1", и. т. д., при каждом очередном вызове
proc nextid_p { prefix } { yield ; for {set i 0} {true} {incr i} { yield "$prefix$i"} }
proc nextid { prefix } { coroutine $prefix nextid_p $prefix }

proc priority_queue {name {subcommand ""} args} {
    # Создаёт команду name, которая функионирует как priority queue с вещественными приоритетами
    # У этой команды есть подкоманды: add, get, len. add с аргументами priority element; get возвращает очередной элемент с минимальным priority, len сообщает, сколько осталось
    # структура queue: {prio:float args}
    switch $subcommand {
        "add" {
            upvar 2 $name queue ;# 2 здесь потому, что priority_queue будет вызываться сквозь вновь созданную субкоманду, т.е. переменная доступна через два уровня
            set nprio [lindex $args 0]
            set min -1
            set max [llength $queue]
            while {$min+1<$max} {
                set mid [expr {($min+$max)/2}]
                if {[lindex $queue $mid 0]>$nprio} {
                    set max $mid
                } else {
                    set min $mid
                }
            }
            set queue [linsert $queue $max $args]
        }
        "get" {
            upvar 2 $name queue
            set item [lindex $queue 0]
            set queue [lreplace $queue [set queue 0] 0]
            return $item
        }
        "del" {
            upvar 2 $name queue
            set tsite [lindex $args 0]
            for {set i 0} {$i<[llength $queue]} {incr i} {
                if {[lindex $queue $i 2]==$tsite} { break }
            }
            set item [lindex $queue $i]
            set queue [lreplace $queue $i $i]
            return $item
        }
        "len" {
            upvar 2 $name queue
            llength $queue
        }
        default {
            upvar 1 $name queue
            proc $name {subcommand args} "priority_queue $name \$subcommand {*}\$args"
            set queue {}
            return $name
        }
    }
}
