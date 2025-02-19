class CreateRunWebhooks < ActiveRecord::Migration[8.0]
  def change
    create_table :run_webhooks do |t|
      t.references :run, null: false, foreign_key: true
      t.string :event_type
      t.jsonb :payload
      t.string :status
      t.integer :attempt_count
      t.datetime :last_attempted_at
      t.text :error_message
      t.string :endpoint_url

      t.timestamps
    end
  end
end
