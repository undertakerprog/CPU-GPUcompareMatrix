#include <iostream>
#include <vector>
#include <random>
#include <chrono>
#include <iomanip>
#include <cstring>
#include <cuda_runtime.h>
#include <curand.h>

using namespace std;

inline size_t idx(size_t r, size_t c, size_t cols) { return r * cols + c; }

#define CUDA_CHECK(call) \
    do { \
        cudaError_t err = call; \
        if (err != cudaSuccess) { \
            cerr << "CUDA Error: " << cudaGetErrorString(err) \
                 << " at " << __FILE__ << ":" << __LINE__ << endl; \
            exit(EXIT_FAILURE); \
        } \
    } while(0)

#define CURAND_CHECK(call) \
    do { \
        curandStatus_t status = call; \
        if (status != CURAND_STATUS_SUCCESS) { \
            cerr << "CURAND Error: " << status \
                 << " at " << __FILE__ << ":" << __LINE__ << endl; \
            exit(EXIT_FAILURE); \
        } \
    } while(0)

// CUDA kernel: Transpose matrix
// Input: rows x cols -> Output: cols x rows
__global__ void transpose_kernel(const int* src, int* dst, size_t rows, size_t cols) {
    size_t i = blockIdx.y * blockDim.y + threadIdx.y;
    size_t j = blockIdx.x * blockDim.x + threadIdx.x;
    
    if (i < rows && j < cols) {
        // dst[j][i] = src[i][j]
        // src: rows x cols, dst: cols x rows
        size_t src_idx = i * cols + j;
        size_t dst_idx = j * rows + i;
        dst[dst_idx] = src[src_idx];
    }
}

__global__ void float_to_int_kernel(const float* src, int* dst, size_t n, float scale, float shift) {
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        dst[idx] = (int)(src[idx] * scale + shift);
    }
}

void print_fragment(const int* a, size_t rows, size_t cols, size_t maxr = 10, size_t maxc = 10) {
    size_t rr = min(rows, maxr);
    size_t cc = min(cols, maxc);
    for (size_t i = 0; i < rr; ++i) {
        for (size_t j = 0; j < cc; ++j) {
            cout << setw(6) << a[idx(i,j,cols)];
        }
        cout << "\n";
    }
}

int main(int argc, char** argv) {
    size_t rows = 1024;
    size_t cols = 1024;
    unsigned int seed = (unsigned int) chrono::system_clock::now().time_since_epoch().count();
    bool quiet = false;
    bool save_result = false;
    bool use_curand = true; // use cuRAND

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--quiet") == 0) {
            quiet = true;
        } else if (strcmp(argv[i], "--save") == 0) {
            save_result = true;
        } else if (strcmp(argv[i], "--cpu-rand") == 0) {
            use_curand = false;
        } else if (i == 1 && argv[i][0] != '-') {
            rows = stoul(argv[i]);
        } else if (i == 2 && argv[i][0] != '-') {
            cols = stoul(argv[i]);
        } else if (i == 3 && argv[i][0] != '-') {
            seed = (unsigned int) stoi(argv[i]);
        }
    }

    if (!quiet) {
        cout << "GPU Version - Matrix " << rows << " x " << cols << ", seed=" << seed << "\n";
        cout << "Random generator: " << (use_curand ? "cuRAND (GPU)" : "mt19937 (CPU)") << "\n";
    }

    size_t size_input = rows * cols * sizeof(int);
    size_t size_output = cols * rows * sizeof(int);
    
    vector<int> h_A(rows * cols);
    vector<int> h_B(cols * rows);

    // Allocate device memory
    int *d_A, *d_B;
    CUDA_CHECK(cudaMalloc(&d_A, size_input));
    CUDA_CHECK(cudaMalloc(&d_B, size_output));

    FILE* f_input = fopen("input.bin", "rb");
    bool use_saved_input = (f_input != nullptr) && save_result;
    
    if (use_saved_input) {
        size_t read_count = fread(h_A.data(), sizeof(int), h_A.size(), f_input);
        fclose(f_input);
        
        if (read_count != h_A.size()) {
            cerr << "Error: Failed to read input data from input.bin\n";
            cerr << "Expected " << h_A.size() << " elements, got " << read_count << "\n";
            exit(EXIT_FAILURE);
        }
        
        if (!quiet) {
            cout << "Loaded input data from CPU (input.bin)\n";
        }
        
        CUDA_CHECK(cudaMemcpy(d_A, h_A.data(), size_input, cudaMemcpyHostToDevice));
        
    } else if (use_curand) {
        float *d_A_float;
        CUDA_CHECK(cudaMalloc(&d_A_float, rows * cols * sizeof(float)));

        curandGenerator_t gen;
        CURAND_CHECK(curandCreateGenerator(&gen, CURAND_RNG_PSEUDO_DEFAULT));
        CURAND_CHECK(curandSetPseudoRandomGeneratorSeed(gen, seed));

        // uniform float [0, 1]
        CURAND_CHECK(curandGenerateUniform(gen, d_A_float, rows * cols));

        int threads = 256;
        int blocks = (rows * cols + threads - 1) / threads;
        float_to_int_kernel<<<blocks, threads>>>(d_A_float, d_A, rows * cols, 2000.0f, -1000.0f);
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaDeviceSynchronize());

        CUDA_CHECK(cudaMemcpy(h_A.data(), d_A, size_input, cudaMemcpyDeviceToHost));

        // cleanup
        CURAND_CHECK(curandDestroyGenerator(gen));
        CUDA_CHECK(cudaFree(d_A_float));
    } else {
        mt19937 rng(seed);
        uniform_int_distribution<int> dist(-1000, 1000);
        for (size_t i = 0; i < h_A.size(); ++i) h_A[i] = dist(rng);

        CUDA_CHECK(cudaMemcpy(d_A, h_A.data(), size_input, cudaMemcpyHostToDevice));
    }

    if (!quiet) {
        cout << "\nInput matrix fragment (top-left):\n";
        print_fragment(h_A.data(), rows, cols);
    }

    // Setup grid and block dimensions
    dim3 blockDim(32, 32);  // 1024 threads per block (> 32 как требуется)
    dim3 gridDim((cols + blockDim.x - 1) / blockDim.x, 
                 (rows + blockDim.y - 1) / blockDim.y);
    
    if (!quiet) {
        cout << "\nGrid: (" << gridDim.x << ", " << gridDim.y << "), Block: (" 
             << blockDim.x << ", " << blockDim.y << ")\n";
        cout << "Total threads per block: " << (blockDim.x * blockDim.y) << "\n";
        cout << "Total blocks in grid: " << (gridDim.x * gridDim.y) << "\n";
    }

    // Create CUDA events for timing
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));

    // Warm-up run
    transpose_kernel<<<gridDim, blockDim>>>(d_A, d_B, rows, cols);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    // Timed run
    CUDA_CHECK(cudaEventRecord(start));
    transpose_kernel<<<gridDim, blockDim>>>(d_A, d_B, rows, cols);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaEventRecord(stop));
    CUDA_CHECK(cudaEventSynchronize(stop));
    
    float ms_time = 0;
    CUDA_CHECK(cudaEventElapsedTime(&ms_time, start, stop));
    float us_time = ms_time * 1000.0f;

    // Copy result back
    CUDA_CHECK(cudaMemcpy(h_B.data(), d_B, size_output, cudaMemcpyDeviceToHost));

    if (quiet) {
        cout << "GPU: " << (long long)us_time << " us (" << (long long)ms_time << " ms)\n";
    } else {
        cout << "\nTranspose operation:\n";
        cout << "Time: " << (long long)us_time << " us (" << (long long)ms_time << " ms)\n";
        cout << "Output dimensions: " << cols << " x " << rows << "\n";
        cout << "Result fragment (top-left):\n";
        print_fragment(h_B.data(), cols, rows);
        cout << "\nGPU Execution completed successfully!\n";
    }

    if (save_result) {
        FILE* f = fopen("gpu_result.bin", "wb");
        if (f) {
            fwrite(h_B.data(), sizeof(int), h_B.size(), f);
            fclose(f);
        }
    }

    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaFree(d_A));
    CUDA_CHECK(cudaFree(d_B));

    return 0;
}