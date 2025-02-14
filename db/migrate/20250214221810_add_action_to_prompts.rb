class AddActionToPrompts < ActiveRecord::Migration[8.0]
  def change
    add_column :prompts, :action, :string
  end
end
