class Run < ApplicationRecord
  belongs_to :flow
  belongs_to :conversation, optional: true
  has_many :prompt_runs, dependent: :destroy
  has_many :prompts, through: :prompt_runs

  has_one_attached :subject_image
  has_one_attached :background_reference
  has_one_attached :subject_video

  has_many_attached :attachments

  before_create :assign_status, if: :status.blank?

  after_create :attach_input_image!, if: :input_image_url?
  after_create :attach_input_attachments!
  after_create :perform!

  # setters

  def variables_string=(json_string)
    self.variables = JSON.parse(json_string) if json_string.present?
  end

  # actions

  def trigger_webhook!
    if webhook_url.present?
      RunWebhook.create!(run: self, event_type: "run.#{status}")
    end
  end

  def perform!
    update!(started_at: Time.current)
    flow.prompts.each do |prompt|
      PromptRun.create!(prompt: prompt, run: self)
    end
  end

  def perform_next_action_based_on_status!(new_status)
    update!(status: new_status)
    update!(completed_at: Time.current) if new_status == "completed"
  end

  def assign_status
    self.status = "pending"
  end

  # helpers

  def previous_response_id
    nil
  end

  def data
    prompt_runs.map(&:data).reduce({}, :merge)
  end

  def output_attachments
    prompt_runs.map(&:attachments).flatten
  end

  def attach_input_image!
    return unless input_image_url.present?

    require "open-uri"
    downloaded_image = URI.open(input_image_url)
    subject_image.attach(io: downloaded_image, filename: "input_image.jpg")
  rescue StandardError => e
    Rails.logger.error "Failed to attach input image: #{e.message}"
  end

  def attach_input_attachments!
    attachment_urls.each do |url|
      attachment = URI.open(url)
      attachments.attach(io: attachment, filename: "input_attachment.jpg")
    rescue StandardError => e
      Rails.logger.error "Failed to attach input attachment: #{e.message}"
    end
  end
end
