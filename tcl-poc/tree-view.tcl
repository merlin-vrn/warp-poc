#!/usr/bin/tclsh

package require Tk

ttk::treeview .tree -yscrollcommand {.vscr set} -columns {level parent_path left_child bp_left left_beach site coo circle right_beach bp_right right_child} 
scrollbar  .vscr -command {.tree yview}
.tree heading level -text "×"
.tree heading parent_path -text "↑"
.tree heading left_child -text "↙"
.tree heading bp_left -text "↤"
.tree heading left_beach -text "⇐"
.tree heading site -text "Site"
.tree heading coo -text "XY"
.tree heading circle -text "Circle"
.tree heading right_beach -text "⇒"
.tree heading bp_right -text "↦"
.tree heading right_child -text "↘"

.tree column #0 -width 400
for {set i 1} {$i<12} {incr i} {
    .tree column #$i -width 40
}

.tree configure -displaycolumns {level bp_left left_beach site right_beach bp_right}

.tree tag bind clickable <ButtonPress-1> {what_is_clicked %x %y}

proc what_is_clicked { x y } {
    set itemid [.tree identify item $x $y]
    set displaycolumn [.tree identify column $x $y]
#    set datacolumn [.tree column $displaycolumn -id]
#    set values [.tree item $itemid -values]
    set id [.tree item $itemid -text]
    if {$displaycolumn=="#0"} {
        set field id
        set value [.tree item $itemid -text]
    } else {
        set field [.tree column $displaycolumn -id]
        set value [.tree set $itemid $displaycolumn]
    }
    puts "$id.$field = $value"
    
}


grid .tree .vscr -sticky nsew
grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1
grid columnconfigure . 1 -weight 0

array set state {e3 {parent e2 path right breakpoint {s3 s4} left a3 right e4} s5 {200 0} e4 {parent e3 path right breakpoint {s4 s5} left a4 right e5} s6 {240 0} e5 {parent e4 path right breakpoint {s5 s6} left a5 right e6} s7 {280 0} e6 {parent e5 path right breakpoint {s6 s7} left a6 right e7} s8 {320 0} e7 {parent e6 path right breakpoint {s7 s8} left a7 right e8} s9 {360 0} e8 {parent e7 path right breakpoint {s8 s9} left a8 right e9} e9 {parent e8 path right breakpoint {s9 s10} left a9 right e10} s10 {400 0} s11 {440 0} s12 {480 0} s13 {520 0} s14 {560 0} s15 {600 0} s16 {0 40} s17 {639 40} T e0 a0 {site s0 parent e15 path left right a16} a1 {site s1 parent e1 left a17 path left right a2} a10 {site s10 parent e10 left a9 path left right a11} a2 {site s2 parent e2 left a1 path left right a3} a11 {site s11 parent e11 left a10 path left right a12} a3 {site s3 parent e3 left a2 path left right a4} a12 {site s12 parent e12 left a11 path left right a13} a4 {site s4 parent e4 left a3 path left right a5} a13 {site s13 parent e13 left a12 path left right a14} a5 {site s5 parent e5 left a4 path left right a6} e10 {parent e9 path right breakpoint {s10 s11} left a10 right e11} a14 {site s14 parent e14 left a13 path left right a15} a6 {site s6 parent e6 left a5 path left right a7} e11 {parent e10 path right breakpoint {s11 s12} left a11 right e12} a15 {site s15 parent e17 left a14 path left right a18 circle c1} a16 {site s16 left a0 right a17 parent e15 path right} a7 {site s7 parent e7 left a6 path left right a8} e12 {parent e11 path right breakpoint {s12 s13} left a12 right e13} a17 {site s0 right a1 left a16 parent e16 path right circle c0} a8 {site s8 parent e8 left a7 path left right a9} e13 {parent e12 path right breakpoint {s13 s14} left a13 right e14} a18 {site s17 left a15 right a19 parent e17 path right} a9 {site s9 parent e9 left a8 path left right a10} e14 {parent e13 path right breakpoint {s14 s15} left a14 right e18} a19 {site s15 left a18 parent e18 path right} e15 {breakpoint {s0 s16} left a0 right a16 parent e16 path left} e16 {breakpoint {s16 s0} left e15 right a17 parent e0 path left} e17 {breakpoint {s15 s17} left a15 right a18 parent e18 path left} e18 {breakpoint {s17 s15} left e17 right a19 parent e14 path right} c0 {20.0 20.0 28.284271247461902 a17} c1 {580.0 58.5125 61.836175951056276 a15} s0 {0 0} s1 {40 0} s2 {80 0} e0 {parent T path {} breakpoint {s0 s1} left e16 right e1} s3 {120 0} e1 {parent e0 path right breakpoint {s1 s2} left a1 right e2} e2 {parent e1 path right breakpoint {s2 s3} left a2 right e3} s4 {160 0}}

array set treeids [list T {}]
set queue [list [list $state(T) 0]]
while {[llength $queue]>0} {
    set queue [lassign $queue item_level]
    lassign $item_level item level
    dict set state($item) level $level
    set parent [dict get $state($item) parent]
    if {[dict get $state($item) path]=="right"} {
        set parent_path "$parent↘"
        set parent_index 1
    } else {
        if {$parent=="T"} {
            set parent_path ""
        } else {
            set parent_path "↙$parent"
        }
        set parent_index 0
    }
    set parent_treeid $treeids($parent)
    if {[string index $item 0]=="e"} {
        lassign [dict get $state($item) breakpoint] bp_left bp_right
        set left [dict get $state($item) left]
        set right [dict get $state($item) right]
        lappend queue [list $left [expr {$level+1}]]
        lappend queue [list $right [expr {$level+1}]]
        set values [list $level $parent_path $left $bp_left "" "" "" "" "" $bp_right $right]
        set tags {edge clickable}
    } else { ;# ...=="a"
        set site [dict get $state($item) site]
        set coo [dict get $state($site)]
        if {[dict exists $state($item) circle]} {
            set circle [dict get $state($item) circle]
        } else {
            set circle ""
        }
        if {[dict exists $state($item) left]} {
            set left_beach [dict get $state($item) left]
        } else {
            set left_beach ""
        }
        if {[dict exists $state($item) right]} {
            set right_beach [dict get $state($item) right]
        } else {
            set right_beach ""
        }
        set values [list $level $parent_path "" "" $left_beach $site $coo $circle $right_beach "" ""]
        set tags {arc clickable}
    }
    set treeids($item) [.tree insert $parent_treeid $parent_index -text $item -values $values -tags $tags]
}
puts [array get state]

set item "a17"
set larc [dict get $state($item) left]
set rarc [dict get $state($item) right]
puts "$larc ([dict get $state($larc) level]) × $item × $rarc ([dict get $state($rarc) level])"

set site [dict get $state($item) site]

set _l $larc
set _r $rarc
set ldiff [expr [dict get $state($larc) level]-[dict get $state($rarc) level]]
if {$ldiff>0} {
    puts "$_l вложено глубже"
    for {set i 0} {$i<$ldiff} {incr i} {
        set _l [dict get $state($_l) parent]
        puts "$_l: [dict get $state($_l) breakpoint] | $site" 
    }
} else {
    puts "$_r вложено глубже"
    for {set i $ldiff} {$i<0} {incr i} {
        set _r [dict get $state($_r) parent]
        puts "$site | $_r: [dict get $state($_r) breakpoint]" 

    }
}
while {$_l!=$_r} {
    set _l [dict get $state($_l) parent]
    set _r [dict get $state($_r) parent]
    puts "$_l: [dict get $state($_l) breakpoint] | $site | $_r: [dict get $state($_r) breakpoint]"
}
