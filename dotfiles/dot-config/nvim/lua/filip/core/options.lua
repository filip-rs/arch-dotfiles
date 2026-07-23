local opt = vim.opt

opt.relativenumber = true
opt.number = true

opt.scrolloff = 8
opt.updatetime = 250
-- Time (ms) to wait for a mapped sequence to complete. The default (1000) is
-- what makes which-key feel like it takes ~1s to pop up; 300 keeps it snappy
-- while still leaving room to finish multi-key maps like `jk`.
opt.timeoutlen = 300

-- tabs & indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.autoindent = true

opt.wrap = false

-- search settings
opt.ignorecase = true
opt.smartcase = true

opt.cursorline = true

opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"

-- backspace
opt.backspace = "indent,eol,start"

-- split windows
opt.splitright = true
opt.splitbelow = true

-- turn off swapfile
opt.swapfile = false

-- disable unused language providers (skips their startup/health work)
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
