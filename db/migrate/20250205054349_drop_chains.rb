class DropChains < ActiveRecord::Migration[8.0]
  def change
    drop_table :chains do |t|
      t.string :name
      t.text :description
      t.timestamps
    end
  end
end
