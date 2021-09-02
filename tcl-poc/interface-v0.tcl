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
    bind $frm.cnv <Motion> [list displaycoo $i %x %y]

}

grid [ttk::button .cmds.l0 -text "<0" -command {loadimage 0} -width 0] -sticky nsew -row 0 -column 0
grid [ttk::button .cmds.save -text "save" -command {savestate} -width 0] -sticky nsew -row 0 -column 1
grid [ttk::button .cmds.load -text "load" -command {loadstate} -width 0] -sticky nsew -row 0 -column 2
grid [ttk::button .cmds.l1 -text "1>" -command {loadimage 1} -width 0] -sticky nsew -row 0 -column 3
grid [ttk::button .cmds.addp -text "+" -command {addpoint_prepare} -width 0] -sticky nsew -row 1 -column 0 -columnspan 2
grid [ttk::button .cmds.delp -text "-" -command {deletepoint} -width 0] -sticky nsew -row 1 -column 2 -columnspan 2

ttk::frame .cmds.treeframe
set tcols {idx x0 y0 x1 y1}
ttk::treeview .cmds.tree -columns $tcols -selectmode browse -show headings
foreach i {0 1 2 3 4} {.cmds.tree column $i -width 40 -anchor e}
foreach j $tcols {.cmds.tree heading $j -text $j -anchor center}
ttk::scrollbar .cmds.vsb -command [list .cmds.tree yview] -orient vertical
.cmds.tree configure -yscrollcommand [list .cmds.vsb set]
grid .cmds.tree -in .cmds.treeframe -sticky nsew
grid .cmds.vsb -in .cmds.treeframe -sticky nsew -row 0 -column 1
grid rowconfigure .cmds.treeframe 0 -weight 1
grid columnconfigure .cmds.treeframe 0 -weight 1

grid .cmds.treeframe -sticky nsew -row 2 -column 0 -columnspan 4
grid rowconfigure .cmds 2 -weight 1

grid [ttk::button .cmds.frmv -text "show morphing window" -width 0 -command morphingwindow] -sticky nsew -row 3 -column 0 -columnspan 4

set coox 0
set cooy 0
grid [ttk::label .cmds.lblx -text "X:" -anchor e] -sticky nsew -row 4 -column 0
grid [ttk::label .cmds.coox -textvariable coox] -sticky nsew -row 4 -column 1
grid [ttk::label .cmds.lbly -text "Y:" -anchor e] -sticky nsew -row 4 -column 2
grid [ttk::label .cmds.cooy -textvariable cooy] -sticky nsew -row 4 -column 3


proc loadimage {i {fname ""}} {
#    global img$i
    global img0 img1 ;# оба изображения - чтобы выбрать бОльший размер
    set img [subst \$img$i]

    # Если файл не указан, открыть диалог
    if {$fname==""} {set fname [tk_getOpenFile -filetypes {{{Portable Network Graphics} {.png} {}}}]}
    if {$fname==""} return

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

proc displaycoo {j x y} {
    global coox cooy
    set coo [calc_cnv_coo $j $x $y]
    set coox [lindex $coo 0]
    set cooy [lindex $coo 1]
}

set pointcount 0
proc addpoint_calculate {j x y} {
    # вызывается при клике на холсте, если было активировано добавление точки командой addpoint_prepare
    # снимаем курсор-крест и привязку
    foreach i {0 1} {
        bind .img$i.cnv <ButtonPress-1> {}
        .img$i.cnv configure -cursor ""
    }
    global pointcount
    set i $pointcount
    incr pointcount
    set l [calc_cnv_coo $j $x $y]
    # точку добавляем в оба холста с одинаковыми координатами
    addpoint $i {*}$l {*}$l
}

# TODO: ttk::treeview для точек вместо массива
proc addpoint {i x0 y0 x1 y1 } {
    # вызывается при щелчке на холсте, через обёртку, рассчитывающие координаты с учётом положения прокрутки
    .cmds.tree insert {} end -id point-$i -values [list $i $x0 $y0 $x1 $y1]
    foreach j {0 1} {
        .img$j.cnv create oval [expr {[subst \$x$j]-2}] [expr {[subst \$y$j]-2}] [expr {[subst \$x$j]+2}] [expr {[subst \$y$j]+2}] -outline #000 -width 1 -activeoutline #0F0 -activewidth 2 -tags [list points point-$i]
        .img$j.cnv bind point-$i <ButtonPress-1> [list pointmovestart $j $i %x %y] 
    }
}

set oldX 0 ;# координаты для относительного сдвига
set oldY 0
proc pointmovestart {j i x y} {
    global oldX oldY ;# координаты точки до сдвига
    bind .img$j.cnv <Motion> [list pointmove $j $i %x %y]
    bind .img$j.cnv <ButtonRelease-1> [list pointmoveend $j $i %x %y]
    set oldX $x
    set oldY $y
    .img$j.cnv configure -cursor none
    # подсветить эту точку на другом холсте
    .img[expr {1-$j}].cnv itemconfigure point-$i -outline #F00 -width 2
    # показать точку в списке
#    .cmds.tree see point-$i
}

proc pointmove {j i x y} {
    # меняет координаты перетаскиваемой точки на одном холсте
    global oldX oldY ;# координаты точки до сдвига
    set shiftX [expr {$x-$oldX}]
    set shiftY [expr {$y-$oldY}]
    .img$j.cnv move point-$i $shiftX $shiftY
    displaycoo $j $x $y
    set oldX $x
    set oldY $y
    .cmds.tree set point-$i x$j [expr {[.cmds.tree set point-$i x$j]+$shiftX}]
    .cmds.tree set point-$i y$j [expr {[.cmds.tree set point-$i y$j]+$shiftY}]
}

proc pointmoveend {j i x y} {
    bind .img$j.cnv <Motion> [list displaycoo $j %x %y]
    bind .img$j.cnv <ButtonRelease-1> {}
    .img$j.cnv configure -cursor ""
    # убрать подсветку на другом холсте
    .img[expr {1-$j}].cnv itemconfigure point-$i -outline #000 -width 1
}

proc deletepoint {{point ""}} {
    if {$point==""} {set point [.cmds.tree selection]}
    if {$point==""} return
    foreach j {0 1} {.img$j.cnv delete $point}
    .cmds.tree delete $point
}

proc savestate {} {
    global img0 img1 pointcount
    set fname [tk_getSaveFile -filetypes {{{Morpher Project} {.morph} {}}}]
    if {$fname==""} return
    set f [open $fname "w"]
    foreach j {0 1} {puts $f "loadimage $j \"[[subst \$img$j] cget -file]\""}
    puts $f "set pointcount $pointcount"
    foreach point [.cmds.tree children {}] {puts $f "addpoint [.cmds.tree item $point -values]"}
    close $f
}

proc loadstate {} {
    global pointcount
    set fname [tk_getOpenFile -filetypes {{{Morpher Project} {.morph} {}}}]
    if {$fname==""} return
    foreach point [.cmds.tree children {}] {deletepoint $point}
    source $fname
}

set morphingwindow_shown 0
proc morphingwindow {} {
    global morphingwindow_shown
    if {$morphingwindow_shown} {
        wm forget .mwin
        set morphingwindow_shown 0
    } else {
        wm manage .mwin
        wm protocol .mwin WM_DELETE_WINDOW morphingwindow
        set morphingwindow_shown 1
        morphingwindow_update
    }
}

frame .mwin

grid [canvas .mwin.cnv] -sticky nsew
grid [ttk::scrollbar .mwin.vsb -command [list .mwin.cnv yview] -orient vertical] -sticky nsew -row 0 -column 1
grid [ttk::scrollbar .mwin.hsb -command [list .mwin.cnv xview] -orient horizontal] -sticky nsew -row 1
grid columnconfigure .mwin 0 -weight 1
grid rowconfigure .mwin 0 -weight 1
.mwin.cnv configure -yscrollcommand [list .mwin.vsb set] -xscrollcommand [list .mwin.hsb set] -scrollregion {0 0 100 100}
set imgM [image create photo -width 100 -height 100]
.mwin.cnv create image 0 0 -anchor nw -image [set imgM] -tags {img}
grid [ttk::frame .mwin.cmds] -sticky nsew -row 2 -column 0 -columnspan 2
grid [ttk::frame .mwin.sclf] -in .mwin.cmds -columnspan 2 -sticky nsew
set frameno 0
set frames 1
proc refineframeno {frameno_arg} {
    global frameno
    set frameno [expr {int($frameno_arg)}]
    redraw_points
}
grid [ttk::scale .mwin.sclf.scal -from 0 -to $frames -orient horizontal -variable frameno -command refineframeno] -sticky nsew
grid columnconfigure .mwin.sclf 0 -weight 1
grid [ttk::label .mwin.sclf.frno -textvariable frameno] -column 1 -row 0 -sticky nsew
grid [ttk::label .mwin.sclf._of_ -text " of "] -column 2 -row 0 -sticky nsew
proc updateframes {} {
    global frameno frames
    .mwin.sclf.scal configure -to $frames
    if {$frameno>$frames} {set frameno $frames}
    redraw_points
}
grid [ttk::spinbox .mwin.sclf.spbx -from 1 -to 300 -increment 1 -command updateframes -width 4 -textvariable frames] -column 3 -row 0 -sticky nsew

set voronoi 0
grid [ttk::checkbutton .mwin.cmds.voronoi -variable voronoi -text "show Voronoi diagram"] -columnspan 2 -sticky nsew
set vectors 0
grid [ttk::checkbutton .mwin.cmds.vectors -variable vectors -text "show morphing vectors and current position dots"] -columnspan 2 -sticky nsew
set picture 0
grid [ttk::checkbutton .mwin.cmds.picture -variable picture -text "show and update morphed picture"] -columnspan 2 -sticky nsew

proc morphingwindow_update {} {
    redraw_vectors
    redraw_points
}

proc redraw_vectors {} {
    foreach point [.cmds.tree children {}] {
        set coos [.cmds.tree item $point -values]
        .mwin.cnv delete vector-[lindex $coos 0]
        .mwin.cnv create line [lreplace $coos 0 0] -fill #000 -tags vector-[lindex $coos 0]
    }
}

proc redraw_points {} {
    global frameno frames
    foreach point [.cmds.tree children {}] {
        set coos [.cmds.tree item $point -values]
        set i [lindex $coos 0]
        set x [expr {int(1.0*([lindex $coos 1]*($frames-$frameno)+[lindex $coos 3]*$frameno)/$frames)}]
        set y [expr {int(1.0*([lindex $coos 2]*($frames-$frameno)+[lindex $coos 4]*$frameno)/$frames)}]
        .mwin.cnv delete point-$i
        .mwin.cnv create oval [expr {$x-2}] [expr {$y-2}] [expr {$x+2}] [expr {$y+2}] -outline #000 -tags point-$i
    }
}
