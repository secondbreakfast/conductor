class PollRunJob < ApplicationJob
  queue_as :default

  def perform(run)
    run.poll
  end
end
