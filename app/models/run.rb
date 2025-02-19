class Run < ApplicationRecord
  belongs_to :flow
  has_many :prompt_runs, dependent: :destroy

  has_one_attached :subject_image
  has_one_attached :background_reference
  has_one_attached :subject_video

  before_create :assign_status, if: :status.blank?

  after_create :attach_input_image!, if: :input_image_url?
  after_create :perform!

  # actions

  def trigger_webhook!
    RunWebhook.create!(run: self, event_type: "run.#{status}")
  end

  def perform!
    flow.prompts.each do |prompt|
      PromptRun.create!(prompt: prompt, run: self)
    end
  end

  def assign_status
    self.status = "pending"
  end

  # helpers

  def data
    prompt_runs.map(&:data).reduce({}, :merge)
  end

  def attach_input_image!
    return unless input_image_url.present?

    require "open-uri"
    downloaded_image = URI.open(input_image_url)
    subject_image.attach(io: downloaded_image, filename: "input_image.jpg")
  rescue StandardError => e
    Rails.logger.error "Failed to attach input image: #{e.message}"
  end
end
