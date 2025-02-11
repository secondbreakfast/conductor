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
    update!(
      response: {
        body: result.parsed_response,
        status: result.code,
        error: result.success? ? nil : result.body
      }
    )
    if result.success?
      PollRunJob.set(wait: 5.seconds).perform_later(self)
    else
      update!(status: "failed")
    end
  end

  def poll
    result = Stability::ApiWrapper.new.get_generation(response.dig("body", "id"))
    if result.present?
      attachments.create!(blob: result)
      update!(status: "completed")
    elsif created_at < 10.minutes.ago
      update!(status: "timed-out")
    else
      PollRunJob.set(wait: 5.seconds).perform_later(self)
    end
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

  def data
    {
      image_url: attachments.first.present? ? Rails.application.routes.url_helpers.rails_blob_url(attachments.first, host: "https://conductor-production-662c.up.railway.app") : nil
    }
  end
end
