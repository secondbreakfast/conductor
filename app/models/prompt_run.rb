class PromptRun < ApplicationRecord
  belongs_to :prompt
  belongs_to :run

  has_many_attached :attachments

  after_commit :perform!, on: :create

  def perform!
    BackgroundRunJob.perform_later(self)
  end

  def perform
    result = Stability::ApiWrapper.new.replace_background_and_relight(
      prompt.subject_image,
      background_prompt: prompt.background_prompt,
      background_reference: prompt.background_reference,
      preserve_original_subject: prompt.preserve_original_subject,
      original_background_depth: prompt.original_background_depth
    )
    attachments.create!(blob: result)
  end
end
