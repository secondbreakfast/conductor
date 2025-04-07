module PromptRunner
  module Chat
    class Openai < Runner
      def run
        # OpenAI-specific run here
        response = call_messages!
        puts response

        prompt_run.update!(
          response: response
        )
        prompt_run.update_with_status!("completed")
      end

      def client
        @client ||= ::OpenAI::Client.new(access_token: Rails.application.credentials.openai_api_key)
      end

      def call_messages!
        params = {
          model: selected_model,
          messages: formatted_messages,
          max_tokens: 1024
        }

        # Add tools and tool_choice if tools are present
        if tools.present?
          params[:tools] = tools

          # Set tool_choice to the first tool if available
          if tools.first && tools.first["name"].present?
            params[:tool_choice] = {
              type: "function",
              function: { name: tools.first["name"] }
            }
          end
        end

        client.chat(parameters: params)
      end

      def selected_model
        prompt_run.prompt.selected_model || "gpt-4-turbo"
      end

      def formatted_messages
        messages = []

        # Add system message if present
        if system_prompt.present?
          messages << { role: "system", content: system_prompt }
        end

        # Add user message with content
        messages << { role: "user", content: formatted_content }

        messages
      end

      def system_prompt
        prompt_run.prompt.system_prompt || "You are a helpful assistant."
      end

      def formatted_content
        # For text-only messages
        if !prompt_run.run.subject_image.attached?
          return prompt_run.run.message
        end

        # For messages with images
        content = []

        # Add image to content if it exists
        if prompt_run.run.subject_image.attached?
          image_url = Rails.application.routes.url_helpers.rails_blob_url(
            prompt_run.run.subject_image,
            only_path: false,
            host: ENV["HOST_URL"] || "http://localhost:3000"
          )

          content << {
            type: "image_url",
            image_url: { url: image_url }
          }
        end

        # Add text message
        content << {
          type: "text",
          text: prompt_run.run.message
        }

        content
      end

      def tools
        # Use the tools from the prompt if available, otherwise return an empty array
        if prompt_run.prompt.tools.present?
          # Convert the tools to OpenAI format
          # The structure is slightly different from Anthropic
          prompt_run.prompt.tools.map do |tool|
            {
              type: "function",
              function: {
                name: tool["name"],
                description: tool["description"],
                parameters: tool["input_schema"]
              }
            }
          end
        else
          [] # OpenAI doesn't require default tools
        end
      end
    end
  end
end
