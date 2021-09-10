#!/usr/bin/env tclsh
package require Tk

grid [ttk::frame .img] [ttk::frame .cmds] -sticky nsew
grid columnconfigure . 0 -weight 1
grid rowconfigure . 0 -weight 1

grid [canvas .img.cnv] -sticky nsew
grid [ttk::scrollbar .img.vsb -command [list .img.cnv yview] -orient vertical] -sticky nsew -row 0 -column 1
grid [ttk::scrollbar .img.hsb -command [list .img.cnv xview] -orient horizontal] -sticky nsew -row 1
grid columnconfigure .img 0 -weight 1
grid rowconfigure .img 0 -weight 1
.img.cnv configure -yscrollcommand [list .img.vsb set] -xscrollcommand [list .img.hsb set] -scrollregion { -50 -50 100 100 }
bind .img.cnv <Motion> [list displaycoo %x %y]

ttk::frame .cmds.treeframe
set tcols {idx x y}
ttk::treeview .cmds.tree -columns $tcols -selectmode browse -show headings
foreach i {0 1 2} {.cmds.tree column $i -width 40 -anchor e}
foreach j $tcols {.cmds.tree heading $j -text $j -anchor center}
ttk::scrollbar .cmds.vsb -command [list .cmds.tree yview] -orient vertical
.cmds.tree configure -yscrollcommand [list .cmds.vsb set]
grid .cmds.tree -in .cmds.treeframe -sticky nsew
grid .cmds.vsb -in .cmds.treeframe -sticky nsew -row 0 -column 1
grid rowconfigure .cmds.treeframe 0 -weight 1
grid columnconfigure .cmds.treeframe 0 -weight 1

grid .cmds.treeframe -sticky nsew -row 1 -column 0 -columnspan 4
grid rowconfigure .cmds 1 -weight 1

set coox 0
set cooy 0
set cirx 0
set ciry 0
set radius 0
set inside_circle +
set points_ccw +
grid [ttk::label .cmds.lbld -text "In:" -anchor e] -sticky nsew -row 2 -column 0
grid [ttk::label .cmds.inci -textvariable inside_circle] -sticky nsew -row 2 -column 1
grid [ttk::label .cmds.lblc -text "CCW:" -anchor e] -sticky nsew -row 2 -column 2
grid [ttk::label .cmds.pccw -textvariable points_ccw] -sticky nsew -row 2 -column 3
grid [ttk::label .cmds.lblr -text "Cr:" -anchor e] -sticky nsew -row 3 -column 0
grid [ttk::label .cmds.radi -textvariable radius] -sticky nsew -row 3 -column 1 -columnspan 3
grid [ttk::label .cmds.lbcx -text "Cx:" -anchor e] -sticky nsew -row 4 -column 0
grid [ttk::label .cmds.cirx -textvariable cirx] -sticky nsew -row 4 -column 1
grid [ttk::label .cmds.lbcy -text "Cy:" -anchor e] -sticky nsew -row 4 -column 2
grid [ttk::label .cmds.ciry -textvariable ciry] -sticky nsew -row 4 -column 3
grid [ttk::label .cmds.lblx -text "X:" -anchor e] -sticky nsew -row 5 -column 0
grid [ttk::label .cmds.coox -textvariable coox] -sticky nsew -row 5 -column 1
grid [ttk::label .cmds.lbly -text "Y:" -anchor e] -sticky nsew -row 5 -column 2
grid [ttk::label .cmds.cooy -textvariable cooy] -sticky nsew -row 5 -column 3

proc calc_cnv_coo {x y} {
    # рассчёт координат щелчка в терминах canvas с учётом положения полос прокрутки
    set xv [.img.cnv xview]
    set yv [.img.cnv yview]
    set scr [.img.cnv cget -scrollregion]
    set cx [expr {int([lindex $xv 0]*[lindex $scr 2]+$x-2)}] ;# -2 это страшное колдунство, почему-то x=0 картинки
    set cy [expr {int([lindex $yv 0]*[lindex $scr 3]+$y-2)}] ;# попадает на x=2 canvas, y так же (рамка и паддинг?)
    return [list $cx $cy]
}

proc displaycoo {x y} {
    global coox cooy
    set coo [calc_cnv_coo $x $y]
    set coox [lindex $coo 0]
    set cooy [lindex $coo 1]
}

proc addpoint {i x y } {
    # вызывается при щелчке на холсте, через обёртку, рассчитывающие координаты с учётом положения прокрутки
    .cmds.tree insert {} end -id point-$i -values [list $i $x $y]
    .img.cnv create oval [expr {[subst \$x]-2}] [expr {[subst \$y]-2}] [expr {[subst \$x]+2}] [expr {[subst \$y]+2}] -outline #000 -width 1 -activeoutline #0F0 -activewidth 2 -tags [list points point-$i]
    # TODO: привязывать событие по тегу один раз, а в обработчике разбираться, какая из точек сработала, примерно так: https://stackoverflow.com/questions/54731677/tkinter-canvas-extract-object-id-from-event
    .img.cnv bind point-$i <ButtonPress-1> [list pointmovestart $i %x %y]
}

.img.cnv create oval 0 0 0 0 -tags circle
.img.cnv create line 0 0 0 0 -tags lineAB
.img.cnv create line 0 0 0 0 -tags lineBC
.img.cnv create line 0 0 0 0 -tags lineCA

addpoint A 100 50
addpoint B 50  150
addpoint C 150 200
addpoint D 200 100



set oldX 0 ;# координаты для относительного сдвига
set oldY 0
proc pointmovestart {i x y} {
    global oldX oldY ;# координаты точки до сдвига
    bind .img.cnv <Motion> [list pointmove $i %x %y]
    bind .img.cnv <ButtonRelease-1> [list pointmoveend $i %x %y]
    set oldX $x
    set oldY $y
    .img.cnv configure -cursor none
    # показать точку в списке
#    .cmds.tree see point-$i
}

proc pointmove {i x y} {
    # меняет координаты перетаскиваемой точки на одном холсте
    global oldX oldY ;# координаты точки до сдвига
    set shiftX [expr {$x-$oldX}]
    set shiftY [expr {$y-$oldY}]
    .img.cnv move point-$i $shiftX $shiftY
    displaycoo $x $y
    set oldX $x
    set oldY $y
    .cmds.tree set point-$i x [expr {[.cmds.tree set point-$i x]+$shiftX}]
    .cmds.tree set point-$i y [expr {[.cmds.tree set point-$i y]+$shiftY}]

    update_geometry
}

proc pointmoveend {i x y} {
    bind .img.cnv <Motion> [list displaycoo %x %y]
    bind .img.cnv <ButtonRelease-1> {}
    .img.cnv configure -cursor ""
}

proc update_geometry { } {
    global cirx ciry radius inside_circle points_ccw
    # извлекаем координаты точек из treeview
    foreach p {A B C D} { 
        set P [.cmds.tree set point-$p] 
        dict with P {
            set ${p}x $x
            set ${p}y $y
        }
    }
    
    # the calculation as per https://math.stackexchange.com/a/1460096
    #     | Ax Ay 1 |
    # M = | Bx By 1 |
    #     | Cx Cy 1 |
    set M [expr $Ax*($By-$Cy)+$Bx*($Cy-$Ay)+$Cx*($Ay-$By)]

    if {$M==0} {
        set x 0
        set y 0
        set r 0

        set points_ccw 0

        set inside_circle ...
    } else {
        set Ar [expr $Ax*$Ax+$Ay*$Ay]
        set Br [expr $Bx*$Bx+$By*$By]
        set Cr [expr $Cx*$Cx+$Cy*$Cy]
        #      | Ax²+Ay² Ay 1 |        | Ax²+Ay² Ax 1 |        | Ax²+Ay² Ax Ay |  
        # Mx = | Bx²+By² By 1 |   My = | Bx²+By² Bx 1 |   Mr = | Bx²+By² Bx By | 
        #      | Cx²+Cy² Cy 1 |        | Cx²+Cy² Cx 1 |        | Cx²+Cy² Cx Cy | 
        set Mx [expr $Ar*($By-$Cy)+$Br*($Cy-$Ay)+$Cr*($Ay-$By)]
        set My [expr $Ar*($Bx-$Cx)+$Br*($Cx-$Ax)+$Cr*($Ax-$Bx)]
        set Mr [expr $Ar*$Bx*$Cy+$Br*$Cx*$Ay+$Cr*$Ax*$By-$Ar*$Cx*$By-$Br*$Ax*$Cy-$Cr*$Bx*$Ay]
        set x [expr $Mx/$M/2]
        set y [expr -$My/$M/2]
        set r [expr sqrt($x*$x+$y*$y+$Mr/$M)]

        if {$M>0} { set points_ccw "+" } else { set points_ccw "-" }

        foreach p {A B C} {
            set r${p}x [expr $[subst ${p}x]-$Dx]
            set r${p}y [expr $[subst ${p}y]-$Dy]
            set r${p}r [expr [subst \$r${p}x*\$r${p}x+\$r${p}y*\$r${p}y]]
        }
        #      | Ax-Dx Ay-Dy (Ax-Dx)²+(Ay-Dy)² |
        # Mi = | Bx-Dx By-Dy (Bx-Dx)²+(By-Dy)² |
        #      | Cx-Dx Cy-Dy (Cx-Dx)²+(Cy-Dy)² |
        set Mi [expr ($rAx*$rBy-$rBx*$rAy)*$rCr+($rBx*$rCy-$rCx*$rBy)*$rAr+($rCx*$rAy-$rAx*$rCy)*$rBr]
        set inside_circle [expr (($Mi>0)!=($M>0))?"No":"Yes"]
    }

    .img.cnv coords lineAB $Ax $Ay $Bx $By
    .img.cnv coords lineBC $Bx $By $Cx $Cy
    .img.cnv coords lineCA $Cx $Cy $Ax $Ay
    .img.cnv coords circle [expr $x-$r] [expr $y-$r] [expr $x+$r] [expr $y+$r]

    set cirx [format %.0f $x]
    set ciry [format %.0f $y]
    set radius [format %.3f $r]
}

update_geometry
