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
    perform_next_prompt!
  end

  def perform_next_prompt!
    unperformed_prompts.limit(1).each do |prompt|
      if prompt.endpoint_type == "ImageToVideo"
        input_attachments.each do |attachment|
          PromptRun.create!(prompt: prompt, run: self, source_attachments: [ attachment.blob ])
        end
      else
        PromptRun.create!(prompt: prompt, run: self)
      end
    end
  end

  def perform_next_action_based_on_status!(_new_status)
    statuses = prompt_runs.pluck(:status)
    if statuses.all? { |s| s == "completed" }
      update!(status: "completed", completed_at: Time.current)
      perform_next_prompt!
    elsif statuses.any? { |s| s == "failed" }
      update!(status: "failed")
    elsif statuses.any? { |s| s == "pending" }
      update!(status: "pending")
    end
    RunWebhookJob.perform_later(self)
  end

  def assign_status
    self.status = "pending"
  end

  def unperformed_prompts
    flow.prompts.order(id: :asc).where.not(id: prompt_runs.pluck(:prompt_id))
  end

  # helpers

  def input_attachments
    (subject_image.attached? ? [ subject_image ] : []) + attachments.to_a
  end

  def previous_response_id
    nil
  end

  def data
    self.reload.prompt_runs.order(:id).map(&:data).reduce({}, :merge)
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
