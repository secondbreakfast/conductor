class Runner
  def self.provider(prompt_run)
    new(prompt_run).provider
  end

  def self.run(prompt_run)
    new(prompt_run).run
  end

  def initialize(prompt_run)
    @prompt_run = prompt_run
    @prompt = prompt_run.prompt
  end

  def prompt_run
    @prompt_run
  end

  def prompt
    @prompt
  end

  def run
    # Common chat logic if needed, or delegate directly to provider-specific runner
    provider_runner.run
  end

  def provider
    provider_runner
  end

  private

    def provider_runner
      begin
        "PromptRunner::#{@prompt_run.endpoint_type}::#{@prompt_run.selected_provider}".constantize.new(@prompt_run)
      rescue
        raise "Unsupported provider and endpoint: #{@prompt_run.selected_provider}::#{@prompt_run.endpoint_type}"
      end
    end
end
