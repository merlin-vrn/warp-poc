namespace eval ansi {

foreach {name value} {r 1 g 2 b 4 c 6 m 5 y 3 wht 7 blk 0} {
    proc $name                  {} "return \033\\\[01\\;3${value}m"
    proc [string toupper $name] {} "return \033\\\[01\\;4${value}m"
    namespace export $name [string toupper $name]
}

proc n {} "return \033\\\[0m"
namespace export n

}
