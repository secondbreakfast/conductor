class RunWebhookJob < ApplicationJob
  queue_as :default

  def perform(run)
    run.trigger_webhook!
  end
end
