class Run < ApplicationRecord
  belongs_to :flow

  after_create :perform!

  def perform!
    
    flow.prompts.each do |prompt|
      PromptRun.create!(prompt: prompt, run: self)
    end
  end
end
