module PromptRunner
  module ImageToImage
    class Openai < Runner
      require "open-uri"
      require "tempfile"

      def run
        puts "Running OpenAI image to image"
        create_image
      end

      def create_image
        puts "Creating image"
        params = {
          prompt: prompt_run.prompt.system_prompt.present? ? "#{prompt_run.prompt.system_prompt}\n\n#{prompt_run.run.message}" : prompt_run.run.message,
          model: prompt_run.prompt.selected_model,
          quality: prompt_run.prompt.quality.present? ? prompt_run.prompt.quality : "auto",
          size: prompt_run.prompt.size.present? ? prompt_run.prompt.size : "1024x1024"
        }

        if input_attachments.any?
          with_open_blobs(input_attachments) do |files|
            params[:image] = files
            result = client.images.edit(parameters: params)
            puts "Result: #{result}"
            handle_result(result)
          end
        else
          result = client.images.generate(parameters: params)
          handle_result(result)
        end
      rescue => e
        puts "Error: #{e.message}"
        prompt_run.update_with_status!("failed")
        Rails.logger.error("Image creation failed: #{e.message}")
      end

      def handle_result(result)
        if result.present? && result["data"]&.first&.dig("b64_json").present?
          # Extract the base64 image data
          image_data = result["data"].first["b64_json"]
          # Decode the base64 image data
          image_file = StringIO.new(Base64.decode64(image_data), "rb") # Ensure binary mode
          # Upload to ActiveStorage
          prompt_run.attachments.attach(io: image_file, filename: "generated_image.png", content_type: "image/png")

          # Update prompt_run with the response
          prompt_run.update!(
            response: {
              body: result,
              status: "completed",
              error: nil
            }
          )
          prompt_run.update_with_status!("completed")
        else
          prompt_run.update_with_status!("failed")
        end
      rescue => e
        prompt_run.update_with_status!("failed")
        Rails.logger.error("Image generation failed: #{e.message}")
      end

      def client
        @client ||= ::OpenAI::Client.new(access_token: Rails.application.credentials.openai_api_key)
      end

      def input_attachments
        [ subject_image, *prompt_run.run.attachments, *prompt.attachments ].compact.take(4)
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

      def background_reference
        if prompt_run.run.background_reference.attached?
          prompt_run.run.background_reference
        elsif prompt.background_reference.attached?
          prompt.background_reference
        else
          nil
        end
      end

      def with_open_blobs(attachments, &block)
        open_first_blob(attachments, [], &block)
      end

      def open_first_blob(remaining_attachments, opened_files, &block)
        if remaining_attachments.empty?
          # All files are open, call the block with all files
          yield opened_files
        else
          # Open the next file and continue recursively
          attachment = remaining_attachments.first
          attachment.blob.open do |file|
            open_first_blob(remaining_attachments[1..-1], opened_files + [ file ], &block)
          end
        end
      end
    end
  end
end
