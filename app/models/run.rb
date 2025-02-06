class Run < ApplicationRecord
  belongs_to :flow
  has_many_attached :attachments
  has_one_attached :background_reference

  after_commit :perform!, on: :create

  def perform!
    BackgroundRunJob.perform_later(self)
  end

  def perform
    result = Stability::ApiWrapper.new.replace_background_and_relight(
      attachments.first,
      # background_prompt: "commercial food photograph, studio, well lit",
      background_reference: background_reference,
      preserve_original_subject: 0.8,
      original_background_depth: 0.65
    )
    attachments.create!(blob: result)
  end
end
