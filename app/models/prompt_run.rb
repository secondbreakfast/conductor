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
      subject_image,
      background_prompt: prompt.background_prompt,
      background_reference: background_reference,
      preserve_original_subject: prompt.preserve_original_subject,
      original_background_depth: prompt.original_background_depth
    )
    attachments.create!(blob: result)
  end

  def subject_image
    if run.subject_image.attached?
      run.subject_image
    elsif prompt.subject_image.attached?
      prompt.subject_image
    else
      nil
    end
  end

  def background_reference
    if run.background_reference.attached?
      run.background_reference
    elsif prompt.background_reference.attached?
      prompt.background_reference
    else
      nil
    end
  end
end
