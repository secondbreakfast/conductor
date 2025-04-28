class Output < ApplicationRecord
  belongs_to :response
  delegate :prompt_run, to: :response
end
