#!/usr/bin/env tclsh
package require Tk

set img [image create photo -file grid-16.png]
set wrp [image create photo -file warp-3.png]
set wrp_scale 20.0

set dst [image create photo -width [image width $img] -height [image height $img]]
pack [label .dst -image $dst]

proc get_shift { x_new y_new } {
    global wrp wrp_scale
    set shiftx [lindex [$wrp get $x_new $y_new] 0]
    set shifty [lindex [$wrp get $x_new $y_new] 1]
    set x_old [expr {$x_new + $wrp_scale*($shiftx - 127)/127.0}]
    set y_old [expr {$y_new + $wrp_scale*($shifty - 127)/127.0}]
    return [list $x_old $y_old]
}

proc rgbtohtmlc { r g b } {
    return [format #%02X%02X%02X $r $g $b]
}

proc get_bilinear { src x y } {
    set maxx [expr {[image width $src]-1}]
    set maxy [expr {[image height $src]-1}]
    set x0 [expr {int(floor($x))}]
    set cx1 [expr {$x-$x0}]
    set x1 [expr {int(ceil($x))}]
    set cx0 [expr {1-$cx1}]
    set y0 [expr {int(floor($y))}]
    set cy1 [expr {$y-$y0}]
    set y1 [expr {int(ceil($y))}]
    set cy0 [expr {1-$cy1}]
    if {$x0<0} {set x0 0} elseif {$x0>$maxx} {set x0 $maxx}
    if {$y0<0} {set y0 0} elseif {$y0>$maxy} {set y0 $maxy}
    if {$x1<0} {set x1 0} elseif {$x1>$maxx} {set x1 $maxx}
    if {$y1<0} {set y1 0} elseif {$y1>$maxy} {set y1 $maxy}
    set p00 [$src get $x0 $y0]
    set p01 [$src get $x0 $y1]
    set p10 [$src get $x1 $y0]
    set p11 [$src get $x1 $y1]
    foreach name [list r g b] i00 $p00 i01 $p01 i10 $p10 i11 $p11 {
        set $name [expr {round(($i00*$cx0+$i10*$cx1)*$cy0+($i01*$cx0+$i11*$cx1)*$cy1)}]
    }
    return [list $r $g $b]
}

proc warp { src shift dst } {
    set width [image width $dst]
    set height [image height $dst]
    global wrp_scale
    puts $wrp_scale
    for {set y 0} {$y<$height} {incr y} {
        for {set x 0} {$x<$width} {incr x} {
            set rgb [get_bilinear $src {*}[$shift $x $y]]
            $dst put [rgbtohtmlc {*}$rgb] -to $x $y
        }
    }
}

for {set i 0} {$i<250} {incr i} { 
    set wrp_scale [expr {$i/10.0}]
    warp $img get_shift $dst
    update
    $dst write [format %04i $i].png
}

#warp $img get_shift $dst
