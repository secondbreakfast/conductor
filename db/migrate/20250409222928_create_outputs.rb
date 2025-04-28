class CreateOutputs < ActiveRecord::Migration[8.0]
  def change
    create_table :outputs do |t|
      t.string :provider_id
      t.text :text
      t.string :content_type
      t.text :annotations
      t.references :response, null: false, foreign_key: true

      t.timestamps
    end
  end
end
