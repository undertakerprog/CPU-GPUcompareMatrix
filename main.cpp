/*
make test_nonsquare
make benchmark
make compare ROWS=8192 COLS=8192
*/

#include <iostream>
#include <vector>
#include <random>
#include <chrono>
#include <iomanip>
#include <cmath>
#include <cstring>

using namespace std;
using clk = chrono::high_resolution_clock;
using us = chrono::microseconds;
using ms = chrono::milliseconds;

inline size_t idx(size_t r, size_t c, size_t cols) { return r * cols + c; }

void transpose(const int* src, int* dst, size_t rows, size_t cols) {
    for (size_t i = 0; i < rows; ++i) {
        for (size_t j = 0; j < cols; ++j) {
            dst[idx(j, i, rows)] = src[idx(i, j, cols)];
        }
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

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--quiet") == 0) {
            quiet = true;
        } else if (strcmp(argv[i], "--save") == 0) {
            save_result = true;
        } else if (i == 1 && argv[i][0] != '-') {
            rows = stoul(argv[i]);
        } else if (i == 2 && argv[i][0] != '-') {
            cols = stoul(argv[i]);
        } else if (i == 3 && argv[i][0] != '-') {
            seed = (unsigned int) stoi(argv[i]);
        }
    }

    if (!quiet) {
        cout << "CPU Version - Matrix " << rows << " x " << cols << ", seed=" << seed << "\n";
    }

    vector<int> A(rows * cols);
    vector<int> B(cols * rows); // transposed dimensions

    // Fill A with random
    mt19937 rng(seed);
    uniform_int_distribution<int> dist(-1000, 1000);
    for (size_t i = 0; i < A.size(); ++i) A[i] = dist(rng);

    if (!quiet) {
        cout << "\nInput matrix fragment (top-left):\n";
        print_fragment(A.data(), rows, cols);
    }

    auto t0 = clk::now();
    transpose(A.data(), B.data(), rows, cols);
    auto t1 = clk::now();
    auto dur_us = chrono::duration_cast<us>(t1 - t0).count();
    auto dur_ms = chrono::duration_cast<ms>(t1 - t0).count();

    if (quiet) {
        cout << "CPU: " << dur_us << " us (" << dur_ms << " ms)\n";
    } else {
        cout << "\nTranspose operation:\n";
        cout << "Time: " << dur_us << " us (" << dur_ms << " ms)\n";
        cout << "Output dimensions: " << cols << " x " << rows << "\n";
        cout << "Result fragment (top-left):\n";
        print_fragment(B.data(), cols, rows);
    }

    if (save_result) {
        // Сохраняем входные данные для GPU
        FILE* f_in = fopen("input.bin", "wb");
        if (f_in) {
            fwrite(A.data(), sizeof(int), A.size(), f_in);
            fclose(f_in);
        }
        
        // Сохраняем результат CPU
        FILE* f = fopen("cpu_result.bin", "wb");
        if (f) {
            fwrite(B.data(), sizeof(int), B.size(), f);
            fclose(f);
        }
    }

    return 0;
}