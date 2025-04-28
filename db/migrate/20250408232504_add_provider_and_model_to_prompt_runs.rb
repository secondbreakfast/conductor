class AddProviderAndModelToPromptRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :prompt_runs, :selected_provider, :string
    add_column :prompt_runs, :model, :string
  end
end
