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
        prompt_run.update_with_status!("completed")
      end

      def client
        @client ||= ::Anthropic::Client.new(access_token: Rails.application.credentials.anthropic_api_key)
      end

      def call_messages!
        params = {
          model: selected_model,
          system: system_prompt,
          messages: messages,
          max_tokens: 1024
        }

        # Add tools and tool_choice if tools are available
        if tools.present?
          params[:tools] = tools

          # Set tool_choice to the first tool if available
          if tools.first && tools.first["name"].present?
            params[:tool_choice] = {
              type: "tool",
              name: tools.first["name"]
            }
          end
        end

        client.messages(parameters: params)
      end

      def selected_model
        prompt_run.prompt.selected_model || "claude-3-sonnet-20240229"
      end

      def system_prompt
        prompt_run.prompt.system_prompt || "You are an assistant."
      end

      def messages
        [ { role: "user", content: message_content } ]
      end

      def message_content
        content = []
        # Add image to content if it exists
        if prompt_run.run.subject_image.attached?
          image_data = Base64.strict_encode64(prompt_run.run.subject_image.download)
          content << {
            type: "image",
            source: {
              type: "base64",
              media_type: prompt_run.run.subject_image.content_type,
              data: image_data
            }
          }
        end
        # Add text message
        content << {
          type: "text",
          text: prompt_run.run.message
        }
        # return content
        content
      end

      def tools
        # Use the tools from the prompt if available, otherwise return a default
        if prompt_run.prompt.tools.present?
          # Convert the JSONB data to a Ruby hash structure
          # The tools are already stored in the proper format for the API
          prompt_run.prompt.tools
        else
          # Default tools as a fallback
          [
            {
              "name": "get_drink_name",
              "description": "Get the name of a drink.",
              "input_schema": {
                "type": "object",
                "properties": {
                  "drink_name": {
                    "type": "string",
                    "description": "The name of a drink, e.g. 'coffee' or 'tea' or 'negroni', etc."
                  }
                },
                "required": [ "drink_name" ]
              }
            }
          ]
        end
      end
    end
  end
end
