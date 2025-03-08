module PromptRunner
  module Chat
    class Anthropic < Runner
      def run
        # Anthropic-specific run here
        response = call_messages!
        puts response

        prompt_run.update!(
          response: response
        )
      end

      def client
        @client ||= ::Anthropic::Client.new(access_token: Rails.application.credentials.anthropic_api_key)
      end

      def call_messages!
        client.messages(
          parameters: {
            model: selected_model,
            system: system_prompt,
            messages: messages,
            max_tokens: 1024
          }
        )
      end

      def selected_model
        prompt_run.prompt.selected_model || "claude-3-sonnet-20240229"
      end

      def system_prompt
        prompt_run.prompt.system_prompt || "You are an assistant."
      end

      def messages
        [ { role: "user", content: prompt_run.run.message } ]
      end
    end
  end
end
