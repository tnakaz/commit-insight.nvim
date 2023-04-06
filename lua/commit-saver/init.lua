local M = {}

function M.show_commit_info(hash)
  local commit_info = M.get_commit_info(hash)
  if not commit_info then
    print('Commit not found')
    return
  end

  local commit_summary = M.generate_commit_summary(commit_info)
  local commit_explanation = M.generate_commit_explanation(commit_summary)
  M.display_commit_explanation(commit_explanation)
end

function M.get_commit_info(hash)
  local cmd = 'git show --pretty=format:"%h %s" --stat ' .. hash
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

function M.generate_commit_summary(commit_info)
  local commit_message = commit_info[1]
  local changed_files = {}
  for i = 2, #commit_info do
    table.insert(changed_files, commit_info[i])
  end

  return {commit_message = commit_message, changed_files = changed_files}
end

function M.display_commit_summary(commit_summary)
  print('Commit Message: ' .. commit_summary.commit_message)
  print('Changed Files:')
  for _, file in ipairs(commit_summary.changed_files) do
    print('  ' .. file)
  end
end

function M.generate_commit_explanation(commit_summary)
  local prompt = "Explain the changes made in the following commit: " ..
                 commit_summary.commit_message .. "\n\nChanged Files:\n" ..
                 table.concat(commit_summary.changed_files, "\n")

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
    max_tokens = 150,
    n = 1,
    stop = nil,
    temperature = 0.5,
  }

  local response = vim.fn.system('curl -s -X POST ' .. url .. ' -H "Content-Type: application/json" -H "Authorization: Bearer ' .. api_key .. '" -d \'' .. vim.fn.json_encode(data) .. '\'')
  local decoded_response = vim.fn.json_decode(response)

 -- Display the raw response for debugging purposes
  -- print("Raw response: " .. vim.inspect(decoded_response))

  if not decoded_response.choices then
    print("Error: Unable to get the GPT-3 response.")
    return ""
  end

  return decoded_response.choices[1].message.content
end

function M.display_commit_explanation(commit_explanation)
  print("Commit Explanation:")
  print(commit_explanation)
  -- Copy the commit explanation to the clipboard
  vim.fn.setreg('+', commit_explanation)
  print("Commit explanation has been copied to the clipboard.")
end

return M
