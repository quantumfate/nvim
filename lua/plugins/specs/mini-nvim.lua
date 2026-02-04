return {
    'nvim-mini/mini.nvim',
    version = false,
    config = function(_, opts)
        require("mini.icons").setup(opts)
        require("mini.icons").mock_nvim_web_devicons()
    end

}
