default:
    @just --list

# create a control flow graph with surya
generate-control-flow:
    surya graph  src/*.sol | dot -Tpng

generate-inheriance-graph:
    surya inheritance src/*.sol | dot -Tpng
