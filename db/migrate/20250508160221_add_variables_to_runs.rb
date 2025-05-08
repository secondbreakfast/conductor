class AddVariablesToRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :runs, :variables, :jsonb, default: {}
  end
end
