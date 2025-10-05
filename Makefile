CXX = g++
NVCC = nvcc
CXXFLAGS = -O2 -std=c++17 -Wall -Wextra
NVCCFLAGS = -O2 -std=c++17 -cudart shared -diag-suppress 1650

TARGET_CPU = matrix_cpu
TARGET_GPU = matrix_gpu
TARGET_CMP = matrix_compare

ROWS = 4096
COLS = 4096
SEED = 42

all: $(TARGET_CPU) $(TARGET_GPU) $(TARGET_CMP)

$(TARGET_CPU): main.cpp
	$(CXX) $(CXXFLAGS) main.cpp -o $(TARGET_CPU)

$(TARGET_GPU): main_gpu.cu
	$(NVCC) $(NVCCFLAGS) -arch=sm_52 -lcudart -lcurand main_gpu.cu -o $(TARGET_GPU)

$(TARGET_CMP): compare.cpp
	$(CXX) $(CXXFLAGS) compare.cpp -o $(TARGET_CMP)

run_cpu: $(TARGET_CPU)
	@echo "========================================="
	@echo "Running CPU version..."
	@echo "========================================="
	./$(TARGET_CPU) $(ROWS) $(COLS) $(SEED)

run_gpu: $(TARGET_GPU)
	@echo "========================================="
	@echo "Running GPU version..."
	@echo "========================================="
	./$(TARGET_GPU) $(ROWS) $(COLS) $(SEED)

compare: all
	@echo "========================================="
	@echo "CPU Implementation"
	@echo "========================================="
	@./$(TARGET_CPU) $(ROWS) $(COLS) $(SEED) --quiet --save
	@echo ""
	@echo "========================================="
	@echo "GPU Implementation"
	@echo "========================================="
	@./$(TARGET_GPU) $(ROWS) $(COLS) $(SEED) --quiet --save
	@./$(TARGET_CMP) $(($(ROWS) * $(COLS)))

test: $(TARGET_CPU) $(TARGET_GPU)
	@echo "Quick test with 512x512 matrix..."
	@./$(TARGET_CPU) 512 512 42
	@echo ""
	@./$(TARGET_GPU) 512 512 42

benchmark: $(TARGET_CPU) $(TARGET_GPU)
	@echo "========================================="
	@echo "Benchmark: 1024x1024"
	@echo "========================================="
	@echo "CPU:"
	@./$(TARGET_CPU) 1024 1024 42 | grep "Time:"
	@echo "GPU:"
	@./$(TARGET_GPU) 1024 1024 42 | grep "Time:"
	@echo ""
	@echo "========================================="
	@echo "Benchmark: 2048x2048"
	@echo "========================================="
	@echo "CPU:"
	@./$(TARGET_CPU) 2048 2048 42 | grep "Time:"
	@echo "GPU:"
	@./$(TARGET_GPU) 2048 2048 42 | grep "Time:"
	@echo ""
	@echo "========================================="
	@echo "Benchmark: 4096x4096"
	@echo "========================================="
	@echo "CPU:"
	@./$(TARGET_CPU) 4096 4096 42 | grep "Time:"
	@echo "GPU:"
	@./$(TARGET_GPU) 4096 4096 42 | grep "Time:"
	@echo ""
	@echo "========================================="
	@echo "Benchmark: 8192x8192"
	@echo "========================================="
	@echo "CPU:"
	@./$(TARGET_CPU) 8192 8192 42 | grep "Time:"
	@echo "GPU:"
	@./$(TARGET_GPU) 8192 8192 42 | grep "Time:"

test_nonsquare: $(TARGET_CPU) $(TARGET_GPU)
	@echo "========================================="
	@echo "Test with non-square matrix: 1024x2048"
	@echo "========================================="
	@./$(TARGET_CPU) 1024 2048 42
	@echo ""
	@./$(TARGET_GPU) 1024 2048 42

custom: $(TARGET_CPU) $(TARGET_GPU)
	@echo "CPU:"
	@./$(TARGET_CPU) $(ROWS) $(COLS) $(SEED)
	@echo ""
	@echo "GPU:"
	@./$(TARGET_GPU) $(ROWS) $(COLS) $(SEED)

clean:
	rm -f $(TARGET_CPU) $(TARGET_GPU) $(TARGET_CMP) cpu_result.bin gpu_result.bin input.bin

.PHONY: all run_cpu run_gpu compare test benchmark custom clean