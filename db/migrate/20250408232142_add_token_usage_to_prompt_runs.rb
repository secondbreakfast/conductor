class AddTokenUsageToPromptRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :prompt_runs, :input_tokens, :integer, default: 0
    add_column :prompt_runs, :output_tokens, :integer, default: 0
    add_column :prompt_runs, :total_tokens, :integer, default: 0
  end
end
