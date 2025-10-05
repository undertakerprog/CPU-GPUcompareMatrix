# CPU-GPUcompareMatrix

## Output 

make compare 
```sh
make compare
g++ -O2 -std=c++17 -Wall -Wextra main.cpp -o matrix_cpu
nvcc -O2 -std=c++17 -cudart shared -diag-suppress 1650 -arch=sm_52 -lcudart -lcurand main_gpu.cu -o matrix_gpu
g++ -O2 -std=c++17 -Wall -Wextra compare.cpp -o matrix_compare
=========================================
CPU Implementation
=========================================
CPU: 103412 us (103 ms)

=========================================
GPU Implementation
=========================================
GPU: 3803 us (3 ms)
========================================
РЕЗУЛЬТАТ СРАВНЕНИЯ:
Сравнено элементов: 16777216

Фрагмент результата (первые 10 элементов):
CPU: -251 87 -973 567 -330 92 -838 157 747 -998 
GPU: -251 87 -973 567 -330 92 -838 157 747 -998 

✓ СОВПАДАЮТ - CPU и GPU дали одинаковый результат
========================================
```

make benchmark

```sh
make benchmark
g++ -O2 -std=c++17 -Wall -Wextra main.cpp -o matrix_cpu
nvcc -O2 -std=c++17 -cudart shared -diag-suppress 1650 -arch=sm_52 -lcudart -lcurand main_gpu.cu -o matrix_gpu
=========================================
Benchmark: 1024x1024
=========================================
CPU:
Time: 5354 us (5 ms)
GPU:
Time: 244 us (0 ms)

=========================================
Benchmark: 2048x2048
=========================================
CPU:
Time: 21892 us (21 ms)
GPU:
Time: 899 us (0 ms)

=========================================
Benchmark: 4096x4096
=========================================
CPU:
Time: 103424 us (103 ms)
GPU:
Time: 3219 us (3 ms)

=========================================
Benchmark: 8192x8192
=========================================
CPU:
Time: 476821 us (476 ms)
GPU:
Time: 15055 us (15 ms)
```
