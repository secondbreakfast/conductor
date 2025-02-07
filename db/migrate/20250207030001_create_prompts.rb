class CreatePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :prompts do |t|
      t.string :type, default: 'Prompt'
      t.text :background_prompt
      t.string :light_source_direction
      t.float :light_source_strength
      t.text :foreground_prompt
      t.text :negative_prompt
      t.float :preserve_original_subject
      t.float :original_background_depth
      t.boolean :keep_original_background
      t.float :seed
      t.string :output_format
      t.references :flow, null: false, foreign_key: true

      t.timestamps
    end
  end
end
