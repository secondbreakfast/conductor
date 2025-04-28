class Response < ApplicationRecord
  belongs_to :prompt_run
  has_many :outputs, dependent: :destroy
end
