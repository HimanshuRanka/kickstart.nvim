-- nvim-jdtls: Full-featured Java LSP with Lombok, refactoring, and per-project workspaces
return {
  'mfussenegger/nvim-jdtls',
  ft = 'java',
  config = function()
    local mason_registry = require 'mason-registry'
    local jdtls_pkg = mason_registry.get_package 'jdtls'
    local jdtls_path = jdtls_pkg:get_install_path()

    -- Lombok agent for @Getter, @Setter, @RequiredArgsConstructor, etc.
    local lombok_jar = vim.fn.glob(jdtls_path .. '/lombok.jar')

    -- Platform-specific config directory
    local config_dir = jdtls_path .. '/config_win'

    -- Per-project workspace directory (keeps index data separate per project)
    local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
    local workspace_dir = vim.fn.stdpath 'data' .. '/jdtls-workspace/' .. project_name

    -- Equinox launcher jar
    local launcher_jar = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar')

    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

    local config = {
      cmd = {
        'java',
        '-Declipse.application=org.eclipse.jdt.ls.core.id1',
        '-Dosgi.bundles.defaultStartLevel=4',
        '-Declipse.product=org.eclipse.jdt.ls.core.product',
        '-Dlog.protocol=true',
        '-Dlog.level=ALL',
        '-Xmx2g',
        '--add-modules=ALL-SYSTEM',
        '--add-opens', 'java.base/java.util=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
        '-javaagent:' .. lombok_jar,
        '-jar', launcher_jar,
        '-configuration', config_dir,
        '-data', workspace_dir,
      },

      root_dir = require('jdtls.setup').find_root { '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' },

      capabilities = capabilities,

      settings = {
        java = {
          signatureHelp = { enabled = true },
          contentProvider = { preferred = 'fernflower' },
          completion = {
            favoriteStaticMembers = {
              'org.junit.jupiter.api.Assertions.*',
              'org.mockito.Mockito.*',
              'org.mockito.ArgumentMatchers.*',
              'org.assertj.core.api.Assertions.*',
              'java.util.Objects.requireNonNull',
              'java.util.Objects.requireNonNullElse',
            },
            importOrder = {
              '#', -- static imports first
              '', -- all non-java imports (project, third-party)
              'java',
              'javax',
              'jakarta',
            },
            filteredTypes = {
              'com.sun.*',
              'io.micrometer.shaded.*',
              'java.awt.*',
              'jdk.*',
              'sun.*',
            },
          },
          sources = {
            organizeImports = {
              starThreshold = 9999,
              staticStarThreshold = 9999,
            },
          },
          codeGeneration = {
            toString = {
              template = '${object.className}{${member.name()}=${member.value}, ${otherMembers}}',
            },
            useBlocks = true,
          },
          inlayHints = {
            parameterNames = {
              enabled = 'all',
            },
          },
        },
      },

      on_attach = function(_, bufnr)
        local jdtls = require 'jdtls'
        local map = function(keys, func, desc, mode)
          mode = mode or 'n'
          vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = 'Java: ' .. desc })
        end

        map('<leader>co', jdtls.organize_imports, '[O]rganize Imports')
        map('<leader>cv', jdtls.extract_variable, 'Extract [V]ariable')
        map('<leader>cc', jdtls.extract_constant, 'Extract [C]onstant')
        map('<leader>cm', jdtls.extract_method, 'Extract [M]ethod', { 'n', 'v' })
      end,
    }

    -- Start or attach jdtls when opening a Java file
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'java',
      callback = function()
        require('jdtls').start_or_attach(config)
      end,
    })
  end,
}
