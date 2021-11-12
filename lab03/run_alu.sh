#b!/bin/bash

source /cad/env/cadence_path.XCELIUM1909

xrun -f dut_lab02.f \
-coverage all \
-covoverwrite
