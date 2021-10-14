#!/usr/bin/env tclsh

# Демонстрация использования библиотеки fortunes-1

source "fortunes-1.tcl"
namespace import Fortunes::compute_voronoi_diagram

puts [compute_voronoi_diagram {{0 0} {1 0} {1 1} {0 1}} 0 0 1 1]
