# Наборы точек для delaunay-0 и fortunes-0

set points1_t {
    { 92  91}
    {546  92}
    {104 396}
    {529 381}
    {246 353}
    {273 353}
    {368 353}
    {399 353}
    {275 265}
    {316 264}
    {275 242}
    {344 230}
    {342 171}
    {275 164}
    {355 198}
    {342 257}
    {246 265}
    {247 138}
    {358 149}
    {245 240}
    {359 250}
    {384 198}
    {273 203}
    {245 191}
    {313 138}
    {310 241}
    {309 162}
    {378 170}
    {377 228}
    {245 217}
    {246 166}
}
set points1 {}
for {set i 0} {$i<640} {incr i 40} {
    lappend points1 [list $i 0]
    lappend points1 [list $i 479]
}
for {set j 0} {$j<480} {incr j 40} {
    lappend points1 [list 0 $j]
    lappend points1 [list 639 $j]
}
foreach p $points1_t {
    lappend points1 $p
}

set points2 {
    {0 0}
    {2 0}
    {4 0}
    {1 2}
    {3 2}
    {2 4}
    {3 6}
    {4 4}
    {5 2}
    {6 0}
}

set points3 {}
for {set i 0} {$i<160} {incr i 40} {
    lappend points3 [list $i 0]
    lappend points3 [list $i 119]
}
for {set j 0} {$j<120} {incr j 40} {
    lappend points3 [list 0 $j]
    lappend points3 [list 159 $j]
}
lappend points3 {80 60}

set points $points1
