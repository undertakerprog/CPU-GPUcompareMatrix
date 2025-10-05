#include <iostream>
#include <vector>
#include <cstdio>
#include <sys/stat.h>

using namespace std;

size_t get_file_size(const char* filename) {
    struct stat st;
    if (stat(filename, &st) == 0) {
        return st.st_size / sizeof(int);
    }
    return 0;
}

int main(int argc, char** argv) {
    size_t total_size = 0;
    
    if (argc >= 2) {
        total_size = stoull(argv[1]);
    } else {
        total_size = get_file_size("cpu_result.bin");
        if (total_size == 0) {
            cerr << "\nОшибка: не могу определить размер файла cpu_result.bin\n";
            cerr << "Usage: " << argv[0] << " <total_elements>\n";
            return 1;
        }
    }

    vector<int> cpu_result(total_size);
    FILE* f_cpu = fopen("cpu_result.bin", "rb");
    if (!f_cpu) {
        cerr << "\nОшибка: не найден файл cpu_result.bin\n";
        return 1;
    }
    size_t read_cpu = fread(cpu_result.data(), sizeof(int), total_size, f_cpu);
    fclose(f_cpu);

    if (read_cpu != total_size) {
        cerr << "\nОшибка: прочитано " << read_cpu << " элементов вместо " << total_size << "\n";
        return 1;
    }

    vector<int> gpu_result(total_size);
    FILE* f_gpu = fopen("gpu_result.bin", "rb");
    if (!f_gpu) {
        cerr << "\nОшибка: не найден файл gpu_result.bin\n";
        return 1;
    }
    size_t read_gpu = fread(gpu_result.data(), sizeof(int), total_size, f_gpu);
    fclose(f_gpu);

    if (read_gpu != total_size) {
        cerr << "\nОшибка: прочитано " << read_gpu << " элементов вместо " << total_size << "\n";
        return 1;
    }

    bool match = true;
    size_t first_diff = 0;
    for (size_t i = 0; i < total_size; ++i) {
        if (cpu_result[i] != gpu_result[i]) {
            match = false;
            first_diff = i;
            break;
        }
    }

    cout << "========================================\n";
    cout << "РЕЗУЛЬТАТ СРАВНЕНИЯ:\n";
    cout << "Сравнено элементов: " << total_size << "\n";
    
    cout << "\nФрагмент результата (первые 10 элементов):\n";
    cout << "CPU: ";
    for (size_t i = 0; i < min(size_t(10), total_size); ++i) {
        cout << cpu_result[i] << " ";
    }
    cout << "\nGPU: ";
    for (size_t i = 0; i < min(size_t(10), total_size); ++i) {
        cout << gpu_result[i] << " ";
    }
    cout << "\n\n";
    
    if (match) {
        cout << "✓ СОВПАДАЮТ - CPU и GPU дали одинаковый результат\n";
    } else {
        cout << "✗ НЕ СОВПАДАЮТ - результаты различаются\n";
        cout << "Первое различие на позиции " << first_diff << ":\n";
        cout << "  CPU: " << cpu_result[first_diff] << "\n";
        cout << "  GPU: " << gpu_result[first_diff] << "\n";
    }
    cout << "========================================\n";

    return match ? 0 : 1;
}