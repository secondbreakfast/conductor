class AddConversationToRuns < ActiveRecord::Migration[8.0]
  def change
    add_reference :runs, :conversation, foreign_key: true, null: true
  end
end 