class CreateResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :responses do |t|
      t.string :provider_id
      t.string :role
      t.string :response_type
      t.string :status
      t.string :call_id
      t.string :name
      t.text :arguments
      t.references :prompt_run, null: false, foreign_key: true

      t.timestamps
    end
  end
end
