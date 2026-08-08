-- ============================================================================
-- 🦊 KRS CONFIG: Gestor de Fuentes y Escala GUI (Font Manager)
-- ============================================================================
-- ¿CÓMO FUNCIONA ESTE MÓDULO?
-- 1. Lee/Guarda la configuración de fuente en un archivo JSON en stdpath("config").
-- 2. Modifica 'vim.o.guifont' dinámicamente y la escala de Neovide (si usas Neovide).
-- 3. Registra comandos de usuario (:FontSizeIncrease, :FontSizeDecrease, :FontSizeReset).
-- 4. Registra atajos de teclado globales (Ctrl + +, Ctrl + -, Ctrl + 0).
-- ============================================================================

local M = {}

-- Configuración por defecto
local font_name = "JetBrainsMono Nerd Font"
local default_size = 14
local min_size = 6
local max_size = 40

-- Ruta del archivo de persistencia JSON: ~/.config/nvim/font_config.json (o AppData/Local/nvim en Windows)
local config_path = vim.fn.stdpath("config") .. "/font_config.json"

-- Función privada: Leer la fuente guardada desde disco
local function read_config()
	local f = io.open(config_path, "r")
	if not f then
		return { font_size = default_size, font_name = font_name }
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" and data.font_size then
		return data
	end
	return { font_size = default_size, font_name = font_name }
end

-- Función privada: Guardar la fuente en disco en formato JSON
local function write_config(data)
	local ok, encoded = pcall(vim.json.encode, data)
	if ok then
		local f = io.open(config_path, "w")
		if f then
			f:write(encoded)
			f:close()
		end
	end
end

-- Cargar datos iniciales
local current_data = read_config()
M.current_size = current_data.font_size or default_size
M.font_name = current_data.font_name or font_name

-- Aplicar tamaño de fuente y actualizar variables de GUI (Neovim GUI / Neovide)
function M.apply_font_size(size)
	-- Limitar tamaño entre min_size y max_size
	size = math.max(min_size, math.min(max_size, size))
	M.current_size = size

	-- Actualizar opción nativa guifont
	local font_str = M.font_name .. ":h" .. tostring(size)
	pcall(function()
		vim.o.guifont = font_str
	end)

	-- Si se está ejecutando en Neovide, ajustar el factor de escala
	if vim.g.neovide then
		pcall(function()
			vim.g.neovide_scale_factor = size / 14.0
		end)
	end

	-- Persistir cambios en JSON
	write_config({
		font_size = size,
		font_name = M.font_name,
	})
end

-- Aumentar tamaño
function M.increase()
	M.apply_font_size(M.current_size + 1)
	vim.notify("🔍 Tamañó de Fuente: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager (KRS)" })
end

-- Disminuir tamaño
function M.decrease()
	M.apply_font_size(M.current_size - 1)
	vim.notify("🔍 Tamañó de Fuente: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager (KRS)" })
end

-- Restablecer tamaño por defecto
function M.reset()
	M.apply_font_size(default_size)
	vim.notify("🔍 Fuente Restablecida: " .. M.current_size .. "pt", vim.log.levels.INFO, { title = "Font Manager (KRS)" })
end

-- Función de inicialización pública
function M.setup()
	-- Aplicar tamaño inicial al arrancar
	M.apply_font_size(M.current_size)

	-- Registrar Comandos de Usuario en Neovim (:FontSizeIncrease, etc.)
	vim.api.nvim_create_user_command("FontSizeIncrease", M.increase, { desc = "Aumentar tamaño de fuente" })
	vim.api.nvim_create_user_command("FontSizeDecrease", M.decrease, { desc = "Disminuir tamaño de fuente" })
	vim.api.nvim_create_user_command("FontSizeReset", M.reset, { desc = "Restablecer tamaño de fuente" })

	-- Registrar Keymaps para modos Normal, Insert, Visual y Terminal
	local modes = { "n", "i", "v", "t" }
	local opts = { noremap = true, silent = true }

	-- Ctrl + +, Ctrl + =, Ctrl + NumpadAdd
	vim.keymap.set(modes, "<C-=>", M.increase, vim.tbl_extend("force", opts, { desc = "Aumentar fuente" }))
	vim.keymap.set(modes, "<C-+>", M.increase, vim.tbl_extend("force", opts, { desc = "Aumentar fuente" }))
	vim.keymap.set(modes, "<C-kPlus>", M.increase, vim.tbl_extend("force", opts, { desc = "Aumentar fuente" }))

	-- Ctrl + -, Ctrl + NumpadMinus
	vim.keymap.set(modes, "<C-->", M.decrease, vim.tbl_extend("force", opts, { desc = "Disminuir fuente" }))
	vim.keymap.set(modes, "<C-kMinus>", M.decrease, vim.tbl_extend("force", opts, { desc = "Disminuir fuente" }))

	-- Ctrl + 0
	vim.keymap.set(modes, "<C-0>", M.reset, vim.tbl_extend("force", opts, { desc = "Restablecer fuente" }))
end

return M
