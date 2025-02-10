class AddInputImageUrlToRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :runs, :input_image_url, :string
  end
end
