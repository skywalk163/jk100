Write-Host "编译 ImGui..."
cd g:\traework\jk100\lib\ui
git clone --depth 1 --branch v1.91.6-docking https://github.com/ocornut/imgui.git imgui_src
Copy-Item imgui_src\imgui.cpp .\imgui\
Copy-Item imgui_src\imgui.h .\imgui\
Copy-Item imgui_src\imgui_widgets.cpp .\imgui\
Copy-Item imgui_src\imgui_draw.cpp .\imgui\
Copy-Item imgui_src\imgui_tables.cpp .\imgui\
Copy-Item imgui_src\backends\imgui_impl_win32.cpp .\imgui\backends\
Copy-Item imgui_src\backends\imgui_impl_win32.h .\imgui\backends\
Copy-Item imgui_src\backends\imgui_impl_dx11.cpp .\imgui\backends\
Copy-Item imgui_src\backends\imgui_impl_dx11.h .\imgui\backends\
gcc -c -O2 -DUNICODE -I./imgui -I./imgui/backends `
  ./imgui/imgui.cpp `
  ./imgui/imgui_widgets.cpp `
  ./imgui/imgui_draw.cpp `
  ./imgui/imgui_tables.cpp `
  ./imgui/backends/imgui_impl_win32.cpp `
  ./imgui/backends/imgui_impl_dx11.cpp `
  -o ./lib/libjk100_imgui.a