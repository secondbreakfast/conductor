module PromptRunner
  module ImageToImage
    class Openai < Runner
      require "open-uri"
      require "tempfile"

      def run
        create_image
      end

      def create_image
        params = {
          prompt: prompt_run.run.message,
          model: prompt_run.prompt.selected_model,
          size: "512x512"
        }

        if subject_image
          # Download the image to a temporary file
          Tempfile.open([ "subject_image", ".jpg" ]) do |file|
            file.binmode
            file.write(URI.open(Rails.application.routes.url_helpers.rails_blob_url(subject_image, only_path: false, host: ENV["HOST_URL"] || "http://localhost:3000")).read)
            file.rewind

            # Pass the file path to the image parameter
            params[:image] = file.path

            # Call the OpenAI API
            result = client.images.edit(parameters: params)
            handle_result(result)
          end
        else
          result = client.images.generate(parameters: params)
          handle_result(result)
        end
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

      def subject_image
        if prompt_run.run.subject_image.attached?
          prompt_run.run.subject_image
        elsif prompt.subject_image.attached?
          prompt.subject_image
        else
          nil
        end
      end
    end
  end
end
