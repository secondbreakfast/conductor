class PromptRun < ApplicationRecord
  belongs_to :prompt
  belongs_to :run

  has_many_attached :source_attachments
  has_many_attached :attachments

  has_many :responses, dependent: :destroy
  has_many :outputs, through: :responses

  delegate :endpoint_type, to: :prompt
  delegate :selected_provider, to: :prompt
  delegate :selected_model, to: :prompt

  after_commit :perform!, on: :create

  def perform!
    if prompt.endpoint_type == "Chat"
      perform
    else
      # perform_later
      puts "Performing prompt run: 'perform!'"
      perform_later
    end
  end

  def perform
    puts "Performing prompt run: 'perform'"
    Runner.run(self)
  end

  def perform_later
    BackgroundRunJob.perform_later(self)
  end

  def update_with_status!(new_status)
    update!(status: new_status)
    run.perform_next_action_based_on_status!(new_status)
  end

  # helpers

  def input_attachments
    if source_attachments.any?
      [ source_attachments, *prompt.attachments ].compact.take(4)
    else
      [ subject_image, *run.attachments, *prompt.attachments ].compact.take(4)
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

  def data
    if prompt.action == "image_to_video" || prompt.endpoint_type == "ImageToVideo"
      {
        video_url: attachments.first.present? ? Rails.application.routes.url_helpers.rails_blob_url(attachments.first, host: "https://conductor-production-662c.up.railway.app") : nil
      }
    elsif prompt.endpoint_type == "VideoToVideo"
      {
        video_url: attachments.first.present? ? Rails.application.routes.url_helpers.rails_blob_url(attachments.first, host: "https://conductor-production-662c.up.railway.app") : nil
      }
    elsif prompt.endpoint_type == "ImageToImage"
      {
        image_url: attachments.first.present? ? Rails.application.routes.url_helpers.rails_blob_url(attachments.first, host: "https://conductor-production-662c.up.railway.app") : nil
      }
    else
      response
    end
  end
end
