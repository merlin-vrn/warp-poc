proc ::tcl::mathfunc::sqr {x} { expr {$x*$x} }

# генератор последовательности
# использование: [nextid name prefix] создаёт команду [name]
# эта команда возвращает последовательно значения "prefix0", "prefix1", и. т. д., при каждом очередном вызове
# если prefix не задан, он равен name
proc nextid_coroutine { prefix } { yield ; for {set i 0} {true} {incr i} { yield "$prefix$i"} }
proc nextid { name { prefix "" } } { if {$prefix==""} { set prefix $name } ; coroutine $name nextid_coroutine $prefix }

# использование очереди: [priority_queue name] создаёт команду [name] (и служебную [name_coroutine])
# добавить элементы: [name add prio ...], причём prio - считается частью элемента
# извлечь первый элемент: [name get]
# подсмотреть первый элемент (не удаляя): [name peek]
# вытащить всю очередь: [name dump]
# узнать длину очереди: [name length]

# очередь с приоритетами
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
