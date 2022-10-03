--
-- layout.lua
--

local floor = math.floor
local max = math.max
local min = math.min

local buf_get_name = vim.api.nvim_buf_get_name
local buf_get_option = vim.api.nvim_buf_get_option
local strwidth = vim.api.nvim_strwidth
local tabpagenr = vim.fn.tabpagenr

--- @type bufferline.buffer
local Buffer = require'bufferline.buffer'

--- @type bufferline.icons
local icons = require'bufferline.icons'

--- @type bufferline.options
local options = require'bufferline.options'

--- @type bufferline.state
local state = require'bufferline.state'

--- The number of sides of each buffer in the tabline.
local SIDES_OF_BUFFER = 2

--- @class bufferline.layout.data
--- @field actual_width integer
--- @field available_width integer
--- @field base_widths integer[]
--- @field buffers_width integer
--- @field padding_width integer
--- @field tabpages_width integer
--- @field used_width integer

--- @class bufferline.Layout
local Layout = {}

--- The number of characters needed to represent the tabpages.
--- @return integer width
function Layout.calculate_tabpages_width()
  local current = tabpagenr()
  local total   = tabpagenr('$')
  if not options.tabpages() or total == 1 then
    return 0
  end
  return 1 + tostring(current):len() + 1 + tostring(total):len() + 1
end

--- Calculate the width of the buffers
--- @return integer sum, integer[] widths
function Layout.calculate_buffers_width()
  local icons_enabled = options.icons()
  local has_icons = (icons_enabled == true) or (icons_enabled == 'both') or (icons_enabled == 'buffer_number_with_icon')
  local has_numbers = icons_enabled == 'both' or icons_enabled == 'numbers'

  local sum = 0
  local widths = {}

  for i, bufnr in ipairs(state.buffers) do
    local buffer_data = state.get_buffer_data(bufnr)
    local buffer_name = buffer_data.name or '[no name]'

    local width = 0
    if buffer_data.closing then
      width = buffer_data.real_width
    else
      width = strwidth(buffer_name) + 1 + -- name + space after name
        strwidth(options['icon_separator_' .. (Buffer.get_activity(bufnr) > 1 and '' or 'in') .. 'active']()) -- separator

      if has_icons then
        local file_icon = icons.get_icon(buf_get_name(bufnr), buf_get_option(bufnr, 'filetype'), '')
        width = width + strwidth(file_icon) + 1 -- icon + space after icon
      end

      if has_numbers then
        width = width + #tostring(i) + 1 -- buffer-index + space after buffer-index
      end

      local is_pinned = state.is_pinned(bufnr)
      if options.closable() or is_pinned then
        width = width + strwidth(is_pinned and options.icon_pinned() or (
          buf_get_option(bufnr, 'modified') and options.icon_close_tab_modified() or options.icon_close_tab()
        )) + 1 -- pin-icon + space after pin-icon
      end
    end

    sum = sum + width
    widths[#widths + 1] = width
  end

  return sum, widths
end

--- Calculate the current layout of the bufferline.
--- @return bufferline.layout.data
function Layout.calculate()
  local available_width = vim.o.columns
  available_width = available_width - state.offset.width

  local used_width, base_widths = Layout.calculate_buffers_width()
  local tabpages_width = Layout.calculate_tabpages_width()

  local buffers_width = available_width - tabpages_width

  local buffers_length               = #state.buffers
  local remaining_width              = max(buffers_width - used_width, 0)
  local remaining_width_per_buffer   = floor(remaining_width / buffers_length)
  local remaining_padding_per_buffer = floor(remaining_width_per_buffer / SIDES_OF_BUFFER)
  local padding_width                = max(options.minimum_padding(), min(remaining_padding_per_buffer, options.maximum_padding()))
  local actual_width                 = used_width + (buffers_length * padding_width * SIDES_OF_BUFFER)

  return {
    actual_width = actual_width,
    available_width = available_width,
    base_widths = base_widths,
    buffers_width = buffers_width,
    padding_width = padding_width,
    tabpages_width = tabpages_width,
    used_width = used_width,
  }
end

--- @return {[integer]: integer} position_by_bufnr
function Layout.calculate_buffers_position_by_buffer_number()
  local current_position = 0
  local layout = Layout.calculate()
  local positions = {}

  for i, buffer_number in ipairs(state.buffers) do
    positions[buffer_number] = current_position
    local width = layout.base_widths[i] + (2 * layout.padding_width)
    current_position = current_position + width
  end

  return positions
end

--- @param base_width integer
--- @param padding_width integer
--- @return integer width
function Layout.calculate_width(base_width, padding_width)
  return base_width + (padding_width * SIDES_OF_BUFFER)
end

return Layout
