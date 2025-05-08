module PromptRunner
  module Chat
    class Openai < Runner
      def run
        # OpenAI-specific run here
        response = call_messages!
        puts response

        # Extract usage information
        usage = response.dig("usage")
        input_tokens = usage&.dig("input_tokens")
        output_tokens = usage&.dig("output_tokens")
        total_tokens = usage&.dig("total_tokens")

        # Extract model information
        model_used = response.dig("model")

        prompt_run.update!(
          response: response,
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          total_tokens: total_tokens,
          selected_provider: prompt_run.prompt.selected_provider, # Get provider from prompt
          model: model_used                                      # Get model from response
        )

        # Create Response and Output records from the response
        create_responses_and_outputs!

        prompt_run.update_with_status!("completed")
      end

      def client
        @client ||= ::OpenAI::Client.new(access_token: Rails.application.credentials.openai_api_key)
      end

      def call_messages!
        params = {
          model: selected_model,
          input: input
        }

        # Add tools if present
        if tools.present?
          params[:tools] = tools
        end

        # Add previous_response_id if this is a follow-up message
        if prompt_run.run.previous_response_id.present?
          params[:previous_response_id] = prompt_run.run.previous_response_id
        end

        response = client.responses.create(parameters: params)
        response

        # # Extract the response text from the new format
        # if response.dig("output", 0, "content", 0, "text").present?
        #   response.dig("output", 0, "content", 0, "text")
        # elsif response.dig("output", 0, "name").present?
        #   # Handle tool call responses
        #   {
        #     tool_name: response.dig("output", 0, "name"),
        #     tool_args: response.dig("output", 0, "parameters")
        #   }
        # else
        #   response # Return full response if format is unexpected
        # end
      end

      def call_messages_with_streaming!
        params = {
          model: selected_model,
          input: formatted_content,
          stream: proc do |chunk, _bytesize|
            if chunk["type"] == "response.output_text.delta"
              print chunk["delta"]
              $stdout.flush
            end
          end
        }

        # Add tools if present
        if tools.present?
          params[:tools] = tools
        end

        # Add previous_response_id if this is a follow-up message
        if prompt_run.run.previous_response_id.present?
          params[:previous_response_id] = prompt_run.run.previous_response_id
        end

        client.responses.create(parameters: params)
      end

      def retrieve_response(response_id)
        client.responses.retrieve(response_id: response_id)
      end

      def delete_response(response_id)
        client.responses.delete(response_id: response_id)
      end

      def selected_model
        prompt_run.prompt.selected_model || "gpt-4o"
      end

      def input
        [
          {
            role: "user",
            content: input_content
          }
        ]
      end

      def input_content
        contents = []

        if prompt_run.run.message.present?
          contents << {
            type: "input_text",
            text: prompt_run.run.message
          }
        end

        if attachment = attachments.first
          contents << {
            type: "input_image",
            image_url: Rails.application.routes.url_helpers.rails_blob_url(
              attachment,
              only_path: false,
              host: ENV["HOST_URL"] || "http://localhost:3000"
            )
          }
        end

        contents
      end

      def attachments
        [ subject_image, *prompt_run.run.attachments, *prompt.attachments ].compact
      end

      def subject_image
        if prompt_run.run.subject_image.attached?
          prompt_run.run.subject_image
        elsif prompt.subject_image.attached?
          prompt.subject_image
        else
          nil
        end
      end

      def prompt
        prompt_run.prompt
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
          prompt_run.prompt.tools.map do |tool|
            {
              type: "function",
              name: tool["name"],
              description: tool["description"],
              parameters: tool["parameters"]
            }
          end
        else
          [] # OpenAI doesn't require default tools
        end
      end

      def create_responses_and_outputs!
        response = prompt_run.response
        # Only proceed if there are outputs in the response
        outputs = response.dig("output")
        return unless outputs.present?

        # Process each output item
        outputs.each do |output_data|
          # Create a Response record
          response_record = prompt_run.responses.create!(
            provider_id: output_data["id"],
            role: output_data["role"],
            response_type: output_data["type"],
            status: output_data["status"],
            call_id: output_data["call_id"],
            name: output_data["name"],
            arguments: output_data["arguments"]
          )

          # Create Output records if content exists
          if output_data["content"].present?
            output_data["content"].each do |content_item|
              response_record.outputs.create!(
                provider_id: content_item["id"],
                text: content_item["text"],
                content_type: content_item["type"],
                annotations: content_item["annotations"].to_json
              )
            end
          end
        end
      end
    end
  end
end
