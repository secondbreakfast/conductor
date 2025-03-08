class AddMessageToRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :runs, :message, :text
  end
end
