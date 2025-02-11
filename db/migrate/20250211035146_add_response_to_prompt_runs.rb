class AddResponseToPromptRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :prompt_runs, :response, :jsonb
  end
end
