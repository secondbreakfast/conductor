class BackgroundRunJob < ApplicationJob
  queue_as :default

  def perform(run)
    run.perform
  end
end
