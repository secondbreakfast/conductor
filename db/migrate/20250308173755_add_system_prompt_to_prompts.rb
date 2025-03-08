class AddSystemPromptToPrompts < ActiveRecord::Migration[8.0]
  def change
    add_column :prompts, :system_prompt, :text
  end
end
