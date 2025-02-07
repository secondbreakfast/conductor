class Run < ApplicationRecord
  belongs_to :flow
  has_many :prompt_runs, dependent: :destroy

  has_one_attached :subject_image
  has_one_attached :background_reference

  after_create :perform!

  def perform!
    flow.prompts.each do |prompt|
      PromptRun.create!(prompt: prompt, run: self)
    end
  end
end
