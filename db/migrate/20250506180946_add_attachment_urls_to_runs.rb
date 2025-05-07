class AddAttachmentUrlsToRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :runs, :attachment_urls, :jsonb, default: []
  end
end
