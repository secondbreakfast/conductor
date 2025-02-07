class CreatePromptRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_runs do |t|
      t.references :prompt, null: false, foreign_key: true
      t.references :run, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
