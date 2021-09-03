#!/usr/bin/env tclsh
package require Tk

# изображение, которое будем искажать
set img [image create photo -file grid-16.png]

# это изображение используется функцией get_shift для задания искажения. В конечном итоге функция отображения будет использовать интерполяцию методом кражи площади
set wrp [image create photo -file warp-3.png]

# масштаб искажения, заданного изображения
set wrp_scale 20.0

# изображение, куда будет помещён результат, отображается на экран
set dst [image create photo -width [image width $img] -height [image height $img]]
pack [label .dst -image $dst]

# Функция отображения f: R²→R², из пространства координат целевого изображения в пространство координат оригинала
proc get_shift { x_new y_new } {
    global wrp wrp_scale
    # красный компонент определяющего изображения указывает смещение по оси x
    set shiftx [lindex [$wrp get $x_new $y_new] 0]
    # зелёный компонент определяющего изображения указывает смещение по оси y
    set shifty [lindex [$wrp get $x_new $y_new] 1]
    # значение компонента 127 означает "нет сдвига", меньшие значения — сдвиг налево/вверх, большие — направо/вниз
    # возможный диапазон -127÷127 приводится к -1.0÷1.0, а затем масштабируется
    set x_old [expr {$x_new + $wrp_scale*($shiftx - 127)/127.0}]
    set y_old [expr {$y_new + $wrp_scale*($shifty - 127)/127.0}]
    # таким образом, точка x_new, y_new получилась из точки x_old, y_old исходного изображения
    return [list $x_old $y_old]
}

# сборка цвета в подходящем формате из числовых компонентов
proc rgbtohtmlc { r g b } {
    return [format #%02X%02X%02X $r $g $b]
}

# билинейная фильтрация для извлечения цвета точки исходного изображения. Функция отображения может выдавать дробные координаты,
# где-то между задаными пикселями, и мы предполагаем цвет в этих координатах основываяс на ближайших соседях
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
    # обрезаем значения координат на границах, чтобы не запросиь несуществующие пикселы
    if {$x0<0} {set x0 0} elseif {$x0>$maxx} {set x0 $maxx}
    if {$y0<0} {set y0 0} elseif {$y0>$maxy} {set y0 $maxy}
    if {$x1<0} {set x1 0} elseif {$x1>$maxx} {set x1 $maxx}
    if {$y1<0} {set y1 0} elseif {$y1>$maxy} {set y1 $maxy}
    set p00 [$src get $x0 $y0]
    set p01 [$src get $x0 $y1]
    set p10 [$src get $x1 $y0]
    set p11 [$src get $x1 $y1]
    # для каждого цветового коипонента каждого из четырёх соседей
    foreach name [list r g b] i00 $p00 i01 $p01 i10 $p10 i11 $p11 {
        # вычисляем взвешенное среднее и назначаем это значение предполагаемым цветом в желаемой точке
        set $name [expr {round(($i00*$cx0+$i10*$cx1)*$cy0+($i01*$cx0+$i11*$cx1)*$cy1)}]
    }
    return [list $r $g $b]
}

# собственно вычисляет искажённое изображение
proc warp { src shift dst } {
    set width [image width $dst]
    set height [image height $dst]
    global wrp_scale
    puts $wrp_scale
    # для каждого пиксела целевого изображения
    for {set y 0} {$y<$height} {incr y} {
        for {set x 0} {$x<$width} {incr x} {
            # мы выясняем координаты точки, из которой появился этот пиксел, и находим, какой цвет был в той точке в исходном изображении
            set rgb [get_bilinear $src {*}[$shift $x $y]]
            # и помещаем этот цвет в целевое изображение
            $dst put [rgbtohtmlc {*}$rgb] -to $x $y
        }
    }
}

# рассчитвает набор кадров, меняя масштаб искажения, это будет выглядеть как постепенно нарастающее искажение
for {set i 0} {$i<250} {incr i} { 
    set wrp_scale [expr {$i/10.0}]
    warp $img get_shift $dst
    # перерисовать экран и записать кадр в файл
    update
    $dst write [format %04i $i].png
}

#warp $img get_shift $dst
