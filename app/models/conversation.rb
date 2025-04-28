class Conversation < ApplicationRecord
  has_many :runs, dependent: :destroy
end
