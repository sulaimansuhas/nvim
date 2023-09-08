--Lightline config
vim.g.lightline = {
    colorscheme = 'nightfly',
    active = {
        left = {
            { 'mode', 'paste' },
            { 'readonly', 'relativepath', 'gitbranch', 'modified', 'Hello' }
        }
    },
    component_function = {
        gitbranch = 'gitbranch#name'
    }
}
