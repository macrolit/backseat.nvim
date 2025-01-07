# Backseat.nvim (Hugging Face Fork)

A neovim plugin that uses LLMs to highlight and explain code readability issues. Get unsolicited advice of dubious quality in never-before-seen quantities!

![image](https://i.postimg.cc/Cx2srNQt/Screenshot-from-2024-10-16-22-50-28.png)



![image](https://i.postimg.cc/brKqF41r/Screenshot-from-2024-10-15-23-04-09.png)

![image](https://i.postimg.cc/13yzhhLV/Screenshot-from-2024-10-16-22-46-01.png)
## Backseat

This is a fork of Backseat.nvim designed to support Hugging Face's free API models, providing AI-powered code review and assistance in Neovim.

## Features

- Support for Hugging Face's free API models
- Custom fewshot prompts loadable from setup configuration
- Additional specialized commands for code analysis
- Improved error handling for API key validation

## Installation

Using your preferred plugin manager, install the fork. For example, with packer.nvim:

lua

`use('yourusername/backseat.nvim')`

## Setup

lua

`require('backseat').setup({     use_huggingface = true,  -- Set to false to use original ChatGPT implementation    hf_api_key = 'your_huggingface_api_key',  -- Required for Hugging Face    custom_fewshot = 'path/to/your/fewshot.txt',  -- Optional: path to custom fewshot prompt    -- Other options... })`



```lua
return {
    "james1236/backseat.nvim",
    config = function()
        require("backseat").setup({
            -- Alternatively, set the env var $HUGGINGFACE_API_KEY by putting "export OPENAI_API_KEY=sk-xxxxx" in your ~/.bashrc
            hf_api_key = '$HUGGINGFACE_API_KEY', -- Get yours from Huggingface.co platform
            hf_model_id = 'meta-llama/Meta-Llama-3-8B-Instruct', --If left empty, defaults to Gemma model
            -- language = 'english', -- Such as 'japanese', 'french', 'pirate', 'LOLCAT'
            -- split_threshold = 100,
            -- highlight = {
            --     icon = '', -- ''
            --     group = 'Comment',
            -- }
            custom_fewshots = {
	            junior_novice = {
	                messages = {
	                        {
	                    role = "system",
	                    content = [[
You are an experienced programmer tasked with adding helpful comments to code for junior or novice programmers.
You only make suggestions on key aspects of the code, trying not to overwhelm the user at all cost. Think about less quantity and more quality tips.
You do not make comments on self-explanatory code. If in doubt, do not make a suggestion.
Focus on explaining:
- Less obvious lines of code
- Programming concepts that might be unfamiliar
- The purpose of specific functions or code blocks
- Any non-trivial algorithms or data structures used
- Language-specific features or syntax that might be confusing
Only add comments to lines that need explanation. Do not suggest on lines that already have comments. Use the format: line=<num>: # <explanatory comment>
Your commentary must be concise, clear, and educational. Place the comment on the appropriate line as the code it refers to.]]
		            },
	                {
	                    role = "user",
	                    content = [[
def quicksort(arr):
    if len(arr) <= 1:
        return arr
    else:
        pivot = arr[len(arr) // 2]
        left = [x for x in arr if x < pivot]
        middle = [x for x in arr if x == pivot]
        right = [x for x in arr if x > pivot]
        return quicksort(left) + middle + quicksort(right)

numbers = [3, 6, 8, 10, 1, 2, 1]
sorted_numbers = quicksort(numbers)
print(sorted_numbers)]]
	                },
	                {
	                    role = "assistant",
	                    content = [[
line=2: # Base case: if the array has 1 or fewer elements, it's already sorted
line=5: # Choose the middle element as the pivot for partitioning]]
	                },
	                {
	                    role = "user",
	                    content = [[
01 import re
02 from collections import Counter
03 
04 def process_text(file_path):
05     with open(file_path, 'r') as file:
06         text = file.read().lower()
07     
08     words = re.findall(r'\b\w+\b', text)
09     word_freq = Counter(words)
10    
11     return word_freq.most_common(10)
12 		# store the result
13 result = process_text('sample.txt')
14 for word, count in result:
15     print(f"{word}: {count}")]]
	                },
	                {
	                    role = "assistant",
	                    content = [[
line=5: # Open the file in read mode using a context manager (with statement)
line=8: # Use regex to find all words in the text, \b represents word boundaries]]
	                },
	               -- You can add more messages here if needed
                    }
                },
                -- You can add more custom fewshot types here
            }
            -- Other options...
        })
    end
}

```

## Usage



## Existing Commands

- `:Backseat`: Run a code review on the current buffer (now defaults to code_review prompt)
- `:BackseatAsk`: Ask a question about the code in the current buffer
- `:BackseatClear`: Clear all Backseat virtual text and signs
- `:BackseatClearLine`: Clear Backseat virtual text and signs for the current line

## New Commands

- `:BackseatReadability`: Analyze code for readability issues
- `:BackseatPerformance`: Evaluate code performance
- `:BackseatSecurity`: Check for potential security vulnerabilities

## Error Handling

The plugin now provides more informative error messages when there are issues with the API key or requests. If an invalid API key is used, you will see an error message when trying to run Backseat commands.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
