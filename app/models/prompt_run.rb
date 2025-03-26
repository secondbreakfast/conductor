class PromptRun < ApplicationRecord
  belongs_to :prompt
  belongs_to :run

  has_many_attached :attachments

  delegate :endpoint_type, to: :prompt
  delegate :selected_provider, to: :prompt
  delegate :selected_model, to: :prompt

  after_commit :perform!, on: :create

  def perform!
    if prompt.endpoint_type == "Chat"
      perform
    else
      perform_later
    end
  end

  def perform
    Runner.run(self)
  end

  def perform_later
    BackgroundRunJob.perform_later(self)
  end

  def poll
    result = Stability::ApiWrapper.new.get_generation(response.dig("body", "id"))
    if result.present?
      attachments.create!(blob: result)
      puts "Attachments created"
      puts "Status is: #{status}"
      update_with_status!("completed")
      puts "Status is now: #{status}"
    elsif created_at < 10.minutes.ago
      update_with_status!("timed-out")
    else
      PollRunJob.set(wait: 5.seconds).perform_later(self)
    end
  end

  def update_with_status!(status)
    update!(status: status)
    run.update!(status: status)
    run.update!(completed_at: Time.current) if status == "completed"
    RunWebhookJob.perform_later(run)
  end

  def data
    if prompt.action == "image_to_video"
      {
        video_url: attachments.first.present? ? Rails.application.routes.url_helpers.rails_blob_url(attachments.first, host: "https://conductor-production-662c.up.railway.app") : nil
      }
    else
      {
        image_url: attachments.first.present? ? Rails.application.routes.url_helpers.rails_blob_url(attachments.first, host: "https://conductor-production-662c.up.railway.app") : nil
      }
    end
  end
end
