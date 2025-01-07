local M = {}


-- Automatically executed on startup
if vim.g.loaded_backseat then
    return
end
vim.g.loaded_backseat = true

require("backseat").setup()
local fewshot = require("backseat.fewshot") -- The training messages
local custom_fewshots = {}
vim.g.backseat_custom_fewshots = vim.g.backseat_custom_fewshots or {}


-- Create namespace for backseat suggestions
local backseatNamespace = vim.api.nvim_create_namespace("backseat")

local function print(msg)
    _G.print("Backseat > " .. msg)
end

local code_review_messages = fewshot.code_review.messages
local security_audit_messages = fewshot.security_audit.messages
local performance_review_messages = fewshot.performance_review.messages
local readability_check_messages = fewshot.readability_check.messages


local function get_fewshot_messages(review_type)
    --print("Debug: Attempting to get fewshot for review type: " .. review_type)
    --print("Debug: Available custom fewshots: " .. vim.inspect(vim.tbl_keys(custom_fewshots)))
    --print("Debug: Available default fewshots: " .. vim.inspect(vim.tbl_keys(fewshot)))
    
    if custom_fewshots[review_type] then
        --print("Debug: Using custom fewshot for " .. review_type)
        return custom_fewshots[review_type].messages
    elseif fewshot[review_type] then
        --print("Debug: Using default fewshot for " .. review_type)
        return fewshot[review_type].messages
    else
        --print("Error: Invalid review type '" .. review_type .. "'")
        return nil
    end
end




M.add_custom_fewshot = function(review_type, messages)
    vim.g.backseat_custom_fewshots = vim.g.backseat_custom_fewshots or {}
    vim.g.backseat_custom_fewshots[review_type] = { messages = messages }
end




local function get_api_key()
    -- Priority: 1. g:backseat_hf_api_key 2. $HUGGINGFACE_API_KEY 3. Prompt user
    local api_key = vim.g.backseat_hf_api_key
    if api_key == nil then
        local key = os.getenv("HUGGINGFACE_API_KEY")
        if key ~= nil then
            return key
        end
        local message =
        "No API key found. Please set hf_api_key in the setup table or set the $HUGGINGFACE_API_KEY environment variable."
        vim.fn.confirm(message, "&OK", 1, "Warning")
        return nil
    end
    return api_key
end

local function get_model_id()
    local model = vim.g.backseat_hf_model_id
    if model == nil then
        if vim.g.backseat_model_id_complained == nil then
            local message =
            "No model id specified. Please set hf_model_id in the setup table. Defaulting to google/gemma-1.1-7b-it for now" -- "gpt-4"
            vim.fn.confirm(message, "&OK", 1, "Warning")
            vim.g.backseat_model_id_complained = 1
            
            local final_model = model or "google/gemma-1.1-7b-it"
                print("Debug: Model ID: " .. final_model)
                return final_model
        end
        return "google/gemma-1.1-7b-it"
    end
    return model
end

local function get_language()
    return vim.g.backseat_language
end

local function get_additional_instruction()
    return vim.g.backseat_additional_instruction or ""
end

local function get_split_threshold()
    return vim.g.backseat_split_threshold
end

local function get_highlight_icon()
    return vim.g.backseat_highlight_icon
end

local function get_highlight_group()
    return vim.g.backseat_highlight_group
end

local function split_long_text(text)
    local lines = vim.split(text, "\n")
    -- Get the width of the screen
    local screenWidth = vim.api.nvim_win_get_width(0) - 20
    -- Split any suggestionLines that are too long
    local newLines = {}
    for _, line in ipairs(lines) do
        if string.len(line) >= screenWidth then
            local splitLines = vim.split(line, " ")
            local currentLine = ""
            for _, word in ipairs(splitLines) do
                if string.len(currentLine) + string.len(word) > screenWidth then
                    table.insert(newLines, currentLine)
                    currentLine = word
                else
                    currentLine = currentLine .. " " .. word
                end
            end
            table.insert(newLines, currentLine)
        else
            table.insert(newLines, line)
        end
    end
    return newLines
end

local function gpt_request(dataJSON, callback, callbackTable)
    local api_key = get_api_key()
    if api_key == nil then
        return nil
    end

    local model_id = get_model_id()  -- Make sure this function is defined and returns the correct model ID
        
        -- Use the parsed data directly, as it's already in the correct format for Hugging Face API
        local hf_dataJSON = dataJSON
        
    

    -- Check if curl is installed
    if vim.fn.executable("curl") == 0 then
        vim.fn.confirm("curl installation not found. Please install curl to use Backseat", "&OK", 1, "Warning")
        return nil
    end

    local curlRequest

    -- Create temp file
    local tempFilePath = vim.fn.tempname()
    local tempFile = io.open(tempFilePath, "w")
    if tempFile == nil then
        print("Error creating temp file")
        return nil
    end
    -- Write dataJSON to temp file
    tempFile:write(hf_dataJSON)
    tempFile:close()

    -- Escape the name of the temp file for command line
    local tempFilePathEscaped = vim.fn.fnameescape(tempFilePath)

    -- Check if the user is on windows
    local isWindows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

    if isWindows ~= true then
        -- Linux
        curlRequest = string.format(
            "curl -s https://api-inference.huggingface.co/models/%s -H \"Content-Type: application/json\" -H \"Authorization: Bearer %s\" --data-binary \"@%s\"",
            model_id,
            api_key,
            tempFilePathEscaped
        )
        
        
    else
        -- Windows
        curlRequest = string.format(
            "curl -s https://api-inference.huggingface.co/models/%s -H \"Content-Type: application/json\" -H \"Authorization: Bearer %s\" --data-binary \"@%s\" & del %s > nul 2>&1",
                    model_id,
                    api_key,
                    tempFilePathEscaped,
                    tempFilePathEscaped
        )
    end

    -- vim.fn.confirm(curlRequest, "&OK", 1, "Warning")

    vim.fn.jobstart(curlRequest, {
        stdout_buffered = true,
        on_stdout = function(_, data, _)
            local response = table.concat(data, "\n")
            --print("Raw API response: " .. response) -- Debug print
            local success, responseTable = pcall(vim.json.decode, response)
    
            if success == false or responseTable == nil then
                if response == nil then
                    response = "nil"
                end
                print("Bad or no response: " .. response)
                return nil
            end
    
            if responseTable.error ~= nil then
                print("API Error: " .. vim.inspect(responseTable.error))
                return nil
            end
    
            callback(responseTable, callbackTable)
    
            -- return response
        end,
        on_stderr = function(_, data, _)
            return data
        end,
        on_exit = function(_, data, _)
            return data
        end,
    })

    -- vim.cmd("sleep 10000m") -- Sleep to give time to read the error messages
end


local function parse_response(response, partNumberString, bufnr)
    local content = response[1].generated_text
    --print("Raw AI response: " .. content) -- Debug print

    -- Find the last occurrence of "assistant:" in the content
    local last_assistant_index = content:reverse():find(":%tnatsissa")
    if not last_assistant_index then
        print("Could not find the assistant's response.")
        return
    end

    -- Extract only the assistant's message
    local assistant_message = content:sub(#content - last_assistant_index + 2)
    --print("Extracted assistant message: " .. assistant_message)-- Debug print

    -- Split the content into lines
    local lines = vim.split(assistant_message, "\n")
    local suggestions = {}
    local buffer_line_count = vim.api.nvim_buf_line_count(bufnr)
    
    local suggestion_count = 0

	-- Process lines to extract suggestions
    for _, line in ipairs(lines) do
            local lineNum, message = line:match("^[Ll]ine%s*=?%s*(%d+):%s*(.+)")
            if not lineNum or not message then
                lineNum, message = line:match("^%s*-%s*[Ll]ine%s+(%d+):%s*(.+)")
            end
            
            if lineNum and message then
                lineNum = tonumber(lineNum)
                suggestion_count = suggestion_count + 1
                
                -- Adjust line number if it's 0
                if lineNum == 0 then
                    lineNum = 1
                end
            
            if lineNum <= buffer_line_count then
                table.insert(suggestions, {lineNum = lineNum, message = message})
            else
                print("Skipping suggestion for line " .. lineNum .. " as it exceeds buffer line count.")
            end
        end
    end

    --print("Parsed " .. suggestion_count .. " valid suggestions.")-- Debug print
    --print("Keeping " .. #suggestions .. " suggestions within buffer line count.")-- Debug print

    if #suggestions == 0 then
        print("No displayable suggestions found.")
    else
        print("Attempting to display " .. #suggestions .. " suggestion(s).")
    end

    -- Act on each suggestion
    local displayed_suggestions = 0
    for _, suggestion in ipairs(suggestions) do
        local message = suggestion.message:gsub("^%s*", "") -- Remove leading spaces
        local newLines = split_long_text(message)

        local pairs = {}
        for _, line in ipairs(newLines) do
            table.insert(pairs, {{line, get_highlight_group()}})
        end

        -- Add suggestion virtual text
        local success, result = pcall(vim.api.nvim_buf_set_extmark, bufnr, backseatNamespace, suggestion.lineNum - 1, 0, {
            virt_text_pos = "eol",
            virt_lines = pairs,
            hl_mode = "combine",
            sign_text = get_highlight_icon(),
            sign_hl_group = get_highlight_group()
        })

        if success then
            displayed_suggestions = displayed_suggestions + 1
        else
            print("Failed to display suggestion for line " .. suggestion.lineNum .. ": " .. result)
        end
    end

    --print("Displayed " .. displayed_suggestions .. " suggestion(s) in the editor.")-- Debug print
end





local function prepare_code_snippet(bufnr, startingLineNumber, endingLineNumber)
    -- print("Preparing code snippet from lines " .. startingLineNumber .. " to " .. endingLineNumber)
    local lines = vim.api.nvim_buf_get_lines(bufnr, startingLineNumber - 1, endingLineNumber, false)

    -- Get the max number of digits needed to display a line number
    local maxDigits = string.len(tostring(#lines + startingLineNumber))
    -- Prepend each line with its line number zero padded to numDigits
    for i, line in ipairs(lines) do
        lines[i] = string.format("%0" .. maxDigits .. "d", i - 1 + startingLineNumber) .. " " .. line
    end

    local text = table.concat(lines, "\n")
    return text
end

local backseat_callback
local function backseat_send_from_request_queue(callbackTable)
    -- Stop if there are no more requests in the queue
    if (#callbackTable.requests == 0) then
        return nil
    end

    -- Get bufname without the path
    local bufname = vim.fn.fnamemodify(vim.fn.bufname(callbackTable.bufnr), ":t")

    if callbackTable.requestIndex == 0 then
        if callbackTable.startingRequestCount == 1 then
            print("Sending " .. bufname .. " (" .. callbackTable.lineCount .. " lines) and waiting for response...")
        else
            print("Sending " ..
            bufname .. " (split into " .. callbackTable.startingRequestCount .. " requests) and waiting for response...")
        end
    end

    -- Get the first request from the queue
    local requestJSON = table.remove(callbackTable.requests, 1)
    callbackTable.requestIndex = callbackTable.requestIndex + 1

    gpt_request(requestJSON, backseat_callback, callbackTable)
end

-- Callback for a backseat request
function backseat_callback(responseTable, callbackTable)
    if responseTable ~= nil and #responseTable > 0 then
        parse_response(responseTable, "", callbackTable.bufnr)
    end

    if callbackTable.requestIndex < callbackTable.startingRequestCount then
        backseat_send_from_request_queue(callbackTable)
    end
end


local backseat = require("backseat")

-- Send the current buffer to the AI for readability feedback
vim.api.nvim_create_user_command("Backseat", function(args)
    local review_type = args.args ~= "" and args.args or "code_review"
    local fewshot_messages = backseat.get_fewshot_messages(review_type)

    if not fewshot_messages then
            return
        end

    -- Rest of your command implementation using fewshot_messages
    local chunk_size = 20  -- Set the chunk size to 20 lines
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local num_chunks = math.ceil(#lines / chunk_size)

    local requests = {}
    for i = 1, num_chunks do
        local start_line = (i - 1) * chunk_size + 1
        local end_line = math.min(i * chunk_size, #lines)
        local chunk_text = prepare_code_snippet(bufnr, start_line, end_line)

        if get_additional_instruction() ~= "" then
            chunk_text = chunk_text .. "\n" .. get_additional_instruction()
        end

        if get_language() ~= "" and get_language() ~= "english" then
            chunk_text = chunk_text .. "\nRespond only in " .. get_language() .. ", but keep the 'line=<num>:' part in english"
        end

        -- Combine fewshot messages with the current code chunk
        local messages = vim.deepcopy(fewshot_messages)
        table.insert(messages, {
            role = "user",
            content = "Analyze the following code chunk (lines " .. start_line .. " to " .. end_line .. "):\n" .. chunk_text
        })

        -- Create the request for Hugging Face API
        local requestJSON = vim.json.encode({
            inputs = table.concat(vim.tbl_map(function(msg)
                return msg.role .. ": " .. msg.content
            end, messages), "\n\n"),
            parameters = {
                max_new_tokens = 400,
                max_length = 612,
                temperature = 0.7,
                top_p = 0.95,
                do_sample = true
            }
        })
        table.insert(requests, requestJSON)
    end

    backseat_send_from_request_queue({
        requests = requests,
        startingRequestCount = num_chunks,
        requestIndex = 0,
        bufnr = bufnr,
        lineCount = #lines,
    })
end, {nargs = "?"})


vim.api.nvim_create_user_command("BackseatReadability", function()
    vim.cmd("Backseat readability_check")
end, {
    desc = "Perform a readability check on the current buffer"
})

vim.api.nvim_create_user_command("BackseatSecurity", function()
    vim.cmd("Backseat security_audit")
end, {
    desc = "Security audit, review code for vulnerabilities"
})

vim.api.nvim_create_user_command("BackseatPerformance", function()
    vim.cmd("Backseat performance_review")
end, {
    desc = "Review code for potential performance improvements"
})


vim.api.nvim_create_user_command("BackseatAsk", function(opts)
    local question = opts.args
    if question == "" then
        print("Please provide a question for BackseatAsk")
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local code = table.concat(lines, "\n")

    local messages = {
        {role = "system", content = "You are an AI assistant helping with code analysis."},
        {role = "user", content = "Here's the code:\n" .. code .. "\n\nQuestion: " .. question}
    }

    -- Use the existing gpt_request function to send the question
    local requestJSON = vim.json.encode({
        inputs = table.concat(vim.tbl_map(function(msg)
            return msg.role .. ": " .. msg.content
        end, messages), "\n\n"),
        parameters = {
            max_new_tokens = 400,
            max_length = 612,
            temperature = 0.7,
            top_p = 0.95,
            do_sample = true
        }
    })

    gpt_request(requestJSON, function(responseTable)
        if responseTable and #responseTable > 0 then
            local answer = responseTable[1].generated_text
            print("Answer: " .. answer)
        else
            print("Failed to get a response.")
        end
    end, {bufnr = bufnr})
end, {nargs = "+"})


-- Clear all backseat virtual text and signs
vim.api.nvim_create_user_command("BackseatClear", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, backseatNamespace, 0, -1)
end, {})

-- Clear backseat virtual text and signs for that line
vim.api.nvim_create_user_command("BackseatClearLine", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local lineNum = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_clear_namespace(bufnr, backseatNamespace, lineNum - 1, lineNum)
end, {})



return M
