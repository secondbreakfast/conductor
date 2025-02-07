class PromptRun < ApplicationRecord
  belongs_to :prompt
  belongs_to :run
end
