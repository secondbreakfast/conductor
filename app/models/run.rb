class Run < ApplicationRecord
  belongs_to :flow
  has_many_attached :attachments

  after_create :perform!

  def perform!
    BackgroundRunJob.perform_later(self)
  end

  def perform
    result = Stability::ApiWrapper.new.replace_background_and_relight(
      attachments.first,
      background_prompt: "commercial food photograph, studio background, well lit",
      preserve_original_subject: 0.7,
      original_background_depth: 0.25
    )
    attachments.create!(blob: result)
  end
end
