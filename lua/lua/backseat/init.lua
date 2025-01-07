local M = {}

local use_huggingface = false  -- Set this to true to default Hugging Face instead of ChatGPT

local custom_fewshots = {}

local default_opts = {
    open_api_key = nil,
    openai_model_id = 'gpt-3.5-turbo',
    hf_api_key = nil,
    hf_model_id = 'google/gemma-1.1-7b-it',
    language = 'english',
    additional_instruction = nil,
    split_threshold = 100,
    custom_fewshots = {},  -- Added this line
    highlight = {
        icon = '',
        group = 'String',
    }
}

function M.setup(opts)
    -- Merge default_opts with opts
    opts = vim.tbl_deep_extend('force', default_opts, opts or {})

    -- Set the module's options
    -- if vim.g.backseat_openai_api_key == nil then
    vim.g.backseat_openai_api_key = opts.openai_api_key
    vim.g.backseat_hf_api_key = opts.hf_api_key
    -- end

    -- if vim.g.backseat_openai_model_id == nil then
    vim.g.backseat_openai_model_id = opts.openai_model_id
    vim.g.backseat_hf_model_id = opts.hf_model_id
    -- end

    -- if vim.g.backseat_language == nil then
    vim.g.backseat_language = opts.language
    -- end

    -- if vim.g.backseat_additional_instruction == nil then
    vim.g.backseat_additional_instruction = opts.additional_instruction
    -- end

    -- if vim.g.backseat_split_threshold == nil then
    vim.g.backseat_split_threshold = opts.split_threshold
    -- end

    -- if vim.g.backseat_highlight_icon == nil then
    vim.g.backseat_highlight_icon = opts.highlight.icon
    -- end

    -- if vim.g.backseat_highlight_group == nil then
    vim.g.backseat_highlight_group = opts.highlight.group
    -- end

    -- Handle custom fewshots
    if opts.custom_fewshots and type(opts.custom_fewshots) == "table" then
                            custom_fewshots = opts.custom_fewshots
                            --print("Debug: Custom fewshots loaded:", vim.inspect(vim.tbl_keys(custom_fewshots)))
        end
end

function M.get_fewshot_messages(review_type)
    if custom_fewshots[review_type] then
        return custom_fewshots[review_type].messages
    else
        local fewshot = require("backseat.fewshot")
        if fewshot[review_type] then
            return fewshot[review_type].messages
        else
            --print("Error: Invalid review type '" .. review_type .. "'")-- Debug
            return nil
        end
    end
end

function M.add_custom_fewshot(review_type, messages)
    custom_fewshots[review_type] = { messages = messages }
    --print("Debug: Added custom fewshot: " .. review_type)
end

return M
