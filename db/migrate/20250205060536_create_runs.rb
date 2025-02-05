class CreateRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :runs do |t|
      t.references :flow, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
