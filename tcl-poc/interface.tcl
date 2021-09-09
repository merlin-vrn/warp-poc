#!/usr/bin/env tclsh
package require Tk

grid [ttk::frame .img0] [ttk::frame .cmds] [ttk::frame .img1] -sticky nsew
grid columnconfigure . 0 -weight 1
grid rowconfigure . 0 -weight 1
grid columnconfigure . 2 -weight 1

foreach i {0 1} {
    set frm .img$i
    grid [canvas $frm.cnv] -sticky nsew
    grid [ttk::scrollbar $frm.vsb -command [list $frm.cnv yview] -orient vertical] -sticky nsew -row 0 -column 1
    grid [ttk::scrollbar $frm.hsb -command [list $frm.cnv xview] -orient horizontal] -sticky nsew -row 1
    grid columnconfigure $frm 0 -weight 1
    grid rowconfigure $frm 0 -weight 1
    $frm.cnv configure -yscrollcommand [list $frm.vsb set] -xscrollcommand [list $frm.hsb set] -scrollregion {0 0 100 100}
    set img$i [image create photo -width 100 -height 100]
    $frm.cnv create image 0 0 -anchor nw -image [set img$i] -tags {img}
}

grid [ttk::button .cmds.l0 -text "<" -command {loadimage 0}] -sticky nsew -row 0 -column 0
grid [ttk::button .cmds.l1 -text ">" -command {loadimage 1}] -sticky nsew -row 0 -column 1
grid [ttk::button .cmds.addp -text "+" -command {addpoint_prepare}] -sticky nsew -row 1 -column 0 -columnspan 2

proc loadimage {i} {
#    global img$i
    global img0 img1 ;# оба изображения - чтобы выбрать бОльший размер
    set img [subst \$img$i]

    set fname [tk_getOpenFile -filetypes {{{Portable Network Graphics} {.png} {}}}]
    $img configure -width 0 -height 0 -file $fname
    
    # размер (scrollregion) обоих холстов ставится таким, чтобы помещалось каждое из изображений.
    set wiNew [image width $img]
    set heNew [image height $img]
    set imgOther [subst \$img[expr {1-$i}]]
    set wiOth [image width $imgOther]
    set heOth [image height $imgOther]
    set screg [list 0 0 [expr {max($wiNew,$wiOth)}] [expr {max($heNew,$heOth)}]]
    foreach j {0 1} {.img$j.cnv configure -scrollregion $screg}
}

proc addpoint_prepare {} {
    # срабатывает по нажатию кнопки "добавить точку"
    foreach j {0 1} {
        .img$j.cnv configure -cursor cross
        # addpoint_calculate считает координаты щелчка в терминах canvas и снимает курсор-крест
        bind .img$j.cnv <ButtonPress-1> [list addpoint_calculate $j %x %y]
    }
}

proc calc_cnv_coo {j x y} {
    # рассчёт координат щелчка в терминах canvas с учётом положения полос прокрутки
    set xv [.img$j.cnv xview]
    set yv [.img$j.cnv yview]
    set scr [.img$j.cnv cget -scrollregion]
    set cx [expr {int([lindex $xv 0]*[lindex $scr 2]+$x-2)}] ;# -2 это страшное колдунство, почему-то x=0 картинки
    set cy [expr {int([lindex $yv 0]*[lindex $scr 3]+$y-2)}] ;# попадает на x=2 canvas, y так же (рамка и паддинг?)
    return [list $cx $cy]
}

proc addpoint_calculate {j x y} {
    # вызывается при клике на холсте, если было активировано добавление точки командой addpoint_prepare
    # снимаем курсор-крест и привязку
    foreach i {0 1} {
        bind .img$i.cnv <ButtonPress-1> {}
        .img$i.cnv configure -cursor ""
    }
    addpoint {*}[calc_cnv_coo $j $x $y]
}

# TODO: ttk::treeview для точек вместо массива
set points(next) 0 ;# набор информации о точках: для i-й точки список вида {x y idx0 idx1}, гдe idx - её индекс в imgX.cnv
proc addpoint {x y} {
    # вызывается при щелчке на холсте, через обёртку, рассчитывающие координаты с учётом положения прокрутки
    global points
    set i $points(next)
    set l [list $x $y]
    incr points(next)
    foreach j {0 1} {
        lappend l [.img$j.cnv create oval [expr {$x-2}] [expr {$y-2}] [expr {$x+2}] [expr {$y+2}] -outline #000 -tags [list points point-$i]]
        .img$j.cnv bind point-$i <ButtonPress-1> [list bp1 $j $i %x %y] 
    }
    set points($i) $l
}

# TODO для следуюших трёх команд: учёт, за какое место хватаем точку; учёт габаритов точки; обновление данных в points или treeview
proc bp1 {j i x y} {
    puts "bp1 $j $i $x $y"
    bind .img$j.cnv <Motion> [list movepoint $j $i %x %y]
    bind .img$j.cnv <ButtonRelease-1> [list releasepoint $j $i %x %y]
    .img$j.cnv configure -cursor none
}

proc movepoint {j i x y} {
    # меняет координаты перетаскиваемой точки на одном холсте
    puts "movepoint $j $i $x $y"
    .img$j.cnv moveto point-$i {*}[calc_cnv_coo $j $x $y]
}

proc releasepoint {j i x y} {
    puts "releasepoint $j $i $x $y"
    bind .img$j.cnv <Motion> {}
    bind .img$j.cnv <ButtonRelease-1> {}
    .img$j.cnv configure -cursor ""
}
