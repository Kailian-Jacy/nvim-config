-- Nil (Nix) Language Server configuration
return {
  cmd = { 'nil' },
  filetypes = { 'nix' },
  root_markers = { 'flake.nix', 'default.nix', 'shell.nix', '.git' },
}
