class AddWebhookUrlToRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :runs, :webhook_url, :string
  end
end
