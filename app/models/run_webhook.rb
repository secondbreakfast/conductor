class RunWebhook < ApplicationRecord
  include HTTParty

  belongs_to :run

  validates :event_type, presence: true
  validates :endpoint_url, presence: true

  before_validation :set_endpoint_url
  before_validation :set_attempt_count
  after_create :deliver_webhook

  def set_endpoint_url
    self.endpoint_url ||= run&.webhook_url
  end

  def set_attempt_count
    self.attempt_count ||= 0
  end

  def deliver_webhook
    return if endpoint_url.blank?

    begin
      response = HTTParty.post(
        endpoint_url,
        body: payload.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      if response.success?
        update(
          status: "delivered",
          attempt_count: attempt_count + 1,
          last_attempted_at: Time.current
        )
      else
        update(
          status: "failed",
          attempt_count: attempt_count + 1,
          last_attempted_at: Time.current,
          error_message: "HTTP #{response.code}: #{response.body}"
        )
      end
    rescue StandardError => e
      update(
        status: "failed",
        attempt_count: attempt_count + 1,
        last_attempted_at: Time.current,
        error_message: e.message
      )
    end
  end

  def payload
    {
      type: event_type,
      data: {
        object: JSON.parse(ApplicationController.renderer.render(
          template: "runs/_run",
          formats: [ :json ],
          locals: { run: run }
        ))
      },
      created: Time.current.to_i
    }
  end
end
