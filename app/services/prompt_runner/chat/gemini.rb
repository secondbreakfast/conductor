module PromptRunner
  module Chat
    class Gemini < Runner
      def run
        # Gemini-specific run here
        response = call_messages!
        puts response

        usage = response.dig("usageMetadata")
        input_tokens = usage&.dig("promptTokenCount")
        output_tokens = usage&.dig("candidatesTokenCount")
        total_tokens = usage&.dig("totalTokenCount")

        model_used = selected_model

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

      def api_key
        Rails.application.credentials.gemini_api_key
      end

      def call_messages!
        params = {
          contents: contents
        }

        if prompt_run.prompt.system_prompt.present?
          params[:systemInstruction] = {
            parts: [
              { text: render_template(prompt_run.prompt.system_prompt) }
            ]
          }
        end

        if tools.present?
          params[:tools] = tools
        end

        url = "https://generativelanguage.googleapis.com/v1beta/models/#{selected_model}:generateContent?key=#{api_key}"

        response = HTTParty.post(
          url,
          headers: { 'Content-Type' => 'application/json' },
          body: params.to_json
        )

        JSON.parse(response.body)
      end

      def call_messages_with_streaming!
        params = {
          contents: contents
        }

        if prompt_run.prompt.system_prompt.present?
          params[:systemInstruction] = {
            parts: [
              { text: render_template(prompt_run.prompt.system_prompt) }
            ]
          }
        end

        if tools.present?
          params[:tools] = tools
        end

        url = "https://generativelanguage.googleapis.com/v1beta/models/#{selected_model}:streamGenerateContent?key=#{api_key}&alt=sse"

        HTTParty.post(
          url,
          headers: { 'Content-Type' => 'application/json' },
          body: params.to_json,
          stream_body: true
        ) do |chunk|
          if chunk.include?("data:")
            json_str = chunk.gsub(/^data: /, '').strip
            next if json_str.empty?

            begin
              data = JSON.parse(json_str)
              if text = data.dig("candidates", 0, "content", "parts", 0, "text")
                print text
                $stdout.flush
              end
            rescue JSON::ParserError
            end
          end
        end
      end

      def selected_model
        prompt_run.prompt.selected_model || "gemini-2.5-flash"
      end

      def contents
        [
          {
            role: "user",
            parts: content_parts
          }
        ]
      end

      # Render template with variables using Mustache
      def render_template(template)
        return template unless prompt_run.run.variables.present?

        Mustache.render(template, prompt_run.run.variables.deep_symbolize_keys)
      end

      def content_parts
        parts = []

        attachments.each do |attachment|
          image_data = Base64.strict_encode64(attachment.download)
          parts << {
            inline_data: {
              mime_type: attachment.content_type,
              data: image_data
            }
          }
        end

        if prompt_run.run.message.present?
          parts << {
            text: render_template(prompt_run.run.message)
          }
        end

        parts
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

      def tools
        if prompt_run.prompt.tools.present?
          [
            {
              function_declarations: prompt_run.prompt.tools.map do |tool|
                {
                  name: tool["name"],
                  description: tool["description"],
                  parameters: tool["parameters"]
                }
              end
            }
          ]
        else
          []
        end
      end

      def create_responses_and_outputs!
        response = prompt_run.response
        candidates = response.dig("candidates")
        return unless candidates.present?

        candidates.each do |candidate|
          content = candidate["content"]
          next unless content.present?

          response_record = prompt_run.responses.create!(
            provider_id: candidate["index"]&.to_s,
            role: content["role"],
            response_type: "message",
            status: candidate["finishReason"],
            call_id: nil,
            name: nil,
            arguments: nil
          )

          if content["parts"].present?
            content["parts"].each_with_index do |part, index|
              if part["text"].present?
                response_record.outputs.create!(
                  provider_id: index.to_s,
                  text: part["text"],
                  content_type: "text",
                  annotations: nil
                )
              elsif part["functionCall"].present?
                response_record.update!(
                  name: part["functionCall"]["name"],
                  arguments: part["functionCall"]["args"]
                )
              end
            end
          end
        end
      end
    end
  end
end
