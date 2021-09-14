proc ::tcl::mathfunc::sqr {x} { expr {$x*$x} }

# генератор последовательности
# использование: [nextid prefix] создаёт команду [prefix]
# эта команда возвращает последовательно значения "prefix0", "prefix1", и. т. д., при каждом очередном вызове
proc nextid_p { prefix } { yield ; for {set i 0} {true} {incr i} { yield "$prefix$i"} }
proc nextid { name prefix } { coroutine $name nextid_p $prefix }

proc priority_queue_coroutine { } {
    set queue {} ;# переменная контекста корутины, в которой будет храниться собственно очередь
    set prev {} ;# сюда будет передаваться результат выполнения команды и выдаваться yield на следующем цикле
    while {true} {
        set input [yield $prev] ;# yield вернёт то, что мы передали корутине в аргументе
        set data [lassign $input cmd] ;# первый элемент input попадёт в cmd, остальные (если есть) в data
        switch $cmd {
            "add" {
                set nprio [lindex $data 0] ;# приоритет элемента - в первом аргументе
                # бинарный поиск позиции в очереди, в которую помещать этот элемент
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
                set queue [linsert $queue $max $data]
                set prev {} ;# у этой команды пустой ответ
            }
            "get" {
                set queue [lassign $queue prev] ;# первый элемент queue попадёт в prev, остальные в queue
            }
            "len" {
                set prev [llength $queue]
            }
        }
    }
}

proc priority_queue { name } {
    set coro ${name}_coroutine
    coroutine $coro priority_queue_coroutine
    proc $name { args } "$coro \$args"
}
