class AddSizeAndQualityToPrompts < ActiveRecord::Migration[8.0]
  def change
    add_column :prompts, :size, :string
    add_column :prompts, :quality, :string
  end
end
