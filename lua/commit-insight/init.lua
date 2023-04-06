local M = {}

local function get_commit_info(hash)
  local cmd = 'git show -U0 --patch --format="" ' .. hash .. ' | grep -v "index\\|+++\\|---"'

  local handle = io.popen(cmd)
  local output = handle:read("*a")
  handle:close()

  if output == "" then
    return nil
  end

  local lines = {}
  for line in output:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  return lines
end

local function generate_commit_summary(commit_info)
  local changes = {}
  for i = 1, #commit_info do
    table.insert(changes, commit_info[i])
  end

  return changes
end

local function calc_cost(prompt)
  local yen_rate = 130
  local per_token_cost = 0.000002
  local weight = prompt/3 -- Roughly 1/3 of the number of characters is equal to one token, so multiply by that as a weight.

  local cost = yen_rate * per_token_cost * weight
  return math.floor(cost * 100 + 0.5) / 100
end

local function generate_commit_explanation(commit_summary)
  local prompt = "##Output Format:\nCommit Summary:[commit summary]\nPurpose:[changes purpose]\nThree important changes:[Bullet points for three important changes]\n\n## Changes:\n" .. table.concat(commit_summary, "\n")

  -- Check the length of the prompt
  local prompt_length_limit = 1000  -- Set a desired length limit
  if #prompt > prompt_length_limit then
    print("Warning: The prompt is too long (" .. tostring(#prompt) .. " characters, which is about " .. tostring(calc_cost(#prompt)) .. " yen).")
    print("Sending a large prompt may result in an incomplete response or an API error.")
    print("Do you want to continue? (y/n)")

    local answer = vim.fn.input("")
    if answer:lower() ~= "y" then
      print("Aborted.")
      return ""
    end
  end

  local api_key = os.getenv("OPENAI_API_KEY")
  if not api_key then
    print("Error: OPENAI_API_KEY environment variable is not set.")
    return ""
  end

  local model_name = "gpt-3.5-turbo"
  local url = "https://api.openai.com/v1/chat/completions"
  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. api_key,
  }

  local data = {
    model = model_name,
    messages = {
      {
        role = "user",
        content = prompt
      }
    },
    max_tokens = 500,
    n = 1,
    stop = nil,
    temperature = 0.5
  }
  local encoded_data = vim.fn.json_encode(data)

  -- Write the encoded_data to a temporary file
  local tmp_filename = os.tmpname()
  local tmp_file = io.open(tmp_filename, "w")
  tmp_file:write(encoded_data)
  tmp_file:close()

  -- Send the request using the temporary file as input data
  local response = vim.fn.system('curl -s -X POST ' .. url .. ' -H "Content-Type: application/json" -H "Authorization: Bearer ' .. api_key .. '" -d "@' .. tmp_filename .. '"')

  os.remove(tmp_filename)

  local decoded_response = vim.fn.json_decode(response)

  if not decoded_response.choices then
    print("Error: Unable to get the response.")
    return ""
  end

  return decoded_response.choices[1].message.content
end

local function display_commit_explanation(commit_explanation)
  print(commit_explanation)
  -- Copy the commit explanation to the clipboard
  vim.fn.setreg('+', commit_explanation)
  print("########################################################")
  print("# Commit explanation has been copied to the clipboard. #")
  print("########################################################")
end

function M.show_commit_info(hash)
  local commit_info = get_commit_info(hash)
  if not commit_info then
    print('Commit not found')
    return
  end

  local commit_summary = generate_commit_summary(commit_info)
  local commit_explanation = generate_commit_explanation(commit_summary)
  if commit_explanation ~= "" then
    display_commit_explanation(commit_explanation)
  end
end

return M
