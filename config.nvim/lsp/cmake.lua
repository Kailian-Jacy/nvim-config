-- CMake Language Server configuration
return {
  cmd = { 'cmake-language-server' },
  filetypes = { 'cmake' },
  root_markers = { 'CMakeLists.txt', 'CMakePresets.json', 'cmake', '.git' },
  init_options = {
    buildDirectory = 'build',
  },
}
