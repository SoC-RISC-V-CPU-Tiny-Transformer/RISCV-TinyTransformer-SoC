# RISC-V & Tiny Transformer SoC

**Trạng thái:** Work in Progress (Đang hoàn thiện RTL & Verification)

Đây là repository chứa mã nguồn mô tả phần cứng (RTL) được viết bằng SystemVerilog cho dự án System-on-Chip (SoC). Hệ thống là sự tích hợp giữa một lõi vi xử lý RISC-V và một bộ gia tốc AI chuyên dụng (Tiny Transformer Accelerator). 

Dự án này được nhóm phát triển với mục tiêu hướng tới các ứng dụng nhúng biên (Edge AI) và đang trong quá trình hoàn thiện. Phần mềm tham chiếu (Golden Model bằng PyTorch) có thể được tìm thấy trong cùng organization.

---

##  Kiến trúc Hệ thống (System Architecture)

Hệ thống bao gồm hai thành phần cốt lõi đang được phát triển và kiểm tra song song:

### 1. Bộ gia tốc Tiny Transformer (AI Accelerator)
Bộ gia tốc được thiết kế chuyên biệt để xử lý các phép toán ma trận trong mô hình Transformer (Vision/Audio), tối ưu hóa luồng dữ liệu và diện tích chip:
* **Systolic Array (SA) & Matrix Multiplication Unit (MMU):** Lõi tính toán chính, kết hợp các Processing Elements (PE) và bộ nhân cộng (MAC) để tăng tốc tối đa phép nhân ma trận (QxK, AttentionxV).
* **Bộ nhớ & Đệm (Memory & Buffers):** Các module `VectorSRAM`, `SkewBuffer`, và `TransposeBuffer` chịu trách nhiệm nạp, luân chuyển và định dạng lại luồng tensor cho khớp với chu kỳ hoạt động của Systolic Array.
* **Hàm kích hoạt (Activation):** Các toán tử phi tuyến tính như `ReLU` và `Softmax` được thiết kế phần cứng riêng biệt.
* Đang phát triển...

### 2. RISC-V CPU & Phân hệ Cache (Cache Subsystem)
* **Core:** Lõi xử lý trung tâm đang trong quá trình hoàn thiện các sub-modules.
* **Cache Subsystem:** Hệ thống phân cấp bộ nhớ đã được cấu trúc với `icache` (Instruction Cache), `dcache` (Data Cache), `write_buffer`, và `bus_arbiter`.
* **Giao tiếp Bus:** Định nghĩa các gói tin và giao thức chuẩn AXI (`axi_pkg.sv`) để đảm bảo băng thông giao tiếp tốc độ cao giữa CPU, bộ nhớ đệm và khối gia tốc.
* Đang phát triển...
