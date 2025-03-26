class AddFieldsToPrompts < ActiveRecord::Migration[8.0]
  def change
    add_column :prompts, :endpoint_type, :string
    add_column :prompts, :selected_model, :string
    add_column :prompts, :selected_provider, :string
  end
end
