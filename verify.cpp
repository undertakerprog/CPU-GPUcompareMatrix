#include <iostream>
#include <vector>
#include <random>
#include <chrono>
#include <iomanip>
#include <cmath>

using namespace std;

inline size_t idx(size_t r, size_t c, size_t cols) { return r * cols + c; }

void rotate180(const float* src, float* dst, size_t rows, size_t cols) {
    for (size_t i = 0; i < rows; ++i) {
        for (size_t j = 0; j < cols; ++j) {
            dst[idx(rows - 1 - i, cols - 1 - j, cols)] = src[idx(i, j, cols)];
        }
    }
}

void reflect_right_left(const float* src, float* dst, size_t rows, size_t cols) {
    for (size_t i = 0; i < rows; ++i) {
        for (size_t j = 0; j < cols; ++j) {
            dst[idx(i, cols - 1 - j, cols)] = src[idx(i, j, cols)];
        }
    }
}

void rotate90Clockwise(const float* src, float* dst, size_t rows, size_t cols) {
    for (size_t i = 0; i < rows; ++i) {
        for (size_t j = 0; j < cols; ++j) {
            dst[idx(j, rows - 1 - i, rows)] = src[idx(i, j, cols)];
        }
    }
}

bool compare_arrays(const float* a, const float* b, size_t n, float eps = 1e-5f) {
    size_t errors = 0;
    float max_diff = 0.0f;
    
    for (size_t i = 0; i < n; ++i) {
        float diff = fabs(a[i] - b[i]);
        if (diff > eps) {
            if (errors < 5) {  // Show first 5 errors
                cout << "  Mismatch at index " << i << ": CPU=" << a[i] 
                     << " GPU=" << b[i] << " diff=" << diff << endl;
            }
            errors++;
            max_diff = max(max_diff, diff);
        }
    }
    
    if (errors > 0) {
        cout << "Total errors: " << errors << " out of " << n 
             << " elements (" << (100.0 * errors / n) << "%)" << endl;
        cout << "Max difference: " << max_diff << endl;
        return false;
    }
    return true;
}

void print_fragment(const float* a, size_t rows, size_t cols, size_t maxr = 5, size_t maxc = 5) {
    size_t rr = min(rows, maxr);
    size_t cc = min(cols, maxc);
    cout << fixed << setprecision(3);
    for (size_t i = 0; i < rr; ++i) {
        cout << "  ";
        for (size_t j = 0; j < cc; ++j) {
            cout << setw(8) << a[idx(i,j,cols)];
        }
        cout << "\n";
    }
}

int main(int argc, char** argv) {
    size_t rows = 512;
    size_t cols = 512;
    unsigned int seed = 42;

    if (argc >= 3) {
        rows = stoul(argv[1]);
        cols = stoul(argv[2]);
    }
    if (argc >= 4) seed = (unsigned int) stoi(argv[3]);

    cout << "=== CPU vs GPU Verification Tool ===\n";
    cout << "Matrix: " << rows << " x " << cols << ", seed=" << seed << "\n\n";

    vector<float> A(rows * cols);
    vector<float> B_cpu(rows * cols);
    vector<float> B_gpu(rows * cols);
    
    // Simulated GPU results for demo
    vector<float> A_rotated(rows * cols);

    // Fill with same random data
    mt19937 rng(seed);
    uniform_real_distribution<float> dist(-1000.0f, 1000.0f);
    for (size_t i = 0; i < A.size(); ++i) A[i] = dist(rng);

    // === TEST 1: Rotate 180° ===
    cout << "Test 1: Rotate 180°\n";
    rotate180(A.data(), B_cpu.data(), rows, cols);
    
    // For demo: simulate GPU result (would come from actual GPU run)
    rotate180(A.data(), B_gpu.data(), rows, cols);
    
    cout << "CPU result (top-left):\n";
    print_fragment(B_cpu.data(), rows, cols);
    
    cout << "\nGPU result (top-left):\n";
    print_fragment(B_gpu.data(), rows, cols);
    
    cout << "\nComparison: ";
    if (compare_arrays(B_cpu.data(), B_gpu.data(), rows * cols)) {
        cout << "✓ PASS - Results match!\n";
    } else {
        cout << "✗ FAIL - Results differ!\n";
    }

    // === TEST 2: Reflect + Rotate 90° ===
    cout << "\n" << string(50, '=') << "\n";
    cout << "Test 2: Reflect right-to-left + Rotate 90° clockwise\n";
    
    // CPU version
    reflect_right_left(A.data(), B_cpu.data(), rows, cols);
    rotate90Clockwise(B_cpu.data(), A_rotated.data(), rows, cols);
    
    // GPU version (simulate)
    reflect_right_left(A.data(), B_gpu.data(), rows, cols);
    vector<float> A_rotated_gpu(cols * rows);
    rotate90Clockwise(B_gpu.data(), A_rotated_gpu.data(), rows, cols);
    
    cout << "Result dims: " << cols << " x " << rows << "\n";
    cout << "CPU result (top-left):\n";
    print_fragment(A_rotated.data(), cols, rows);
    
    cout << "\nGPU result (top-left):\n";
    print_fragment(A_rotated_gpu.data(), cols, rows);
    
    cout << "\nComparison: ";
    if (compare_arrays(A_rotated.data(), A_rotated_gpu.data(), cols * rows)) {
        cout << "✓ PASS - Results match!\n";
    } else {
        cout << "✗ FAIL - Results differ!\n";
    }

    cout << "\n=== Verification Complete ===\n";
    cout << "Note: This tool shows the verification logic.\n";
    cout << "In practice, you would load actual GPU output files or\n";
    cout << "integrate GPU code directly to compare results.\n";

    return 0;
}