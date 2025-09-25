module PromptRunner
  module ImageToVideo
    class Gemini < Runner
      require "open-uri"
      require "base64"
      require "json"
      require "tempfile"
      include HTTParty

      base_uri "https://us-central1-aiplatform.googleapis.com"

      def run
        create_video
      end

      private

      def create_video
        # Build the prompt text
        prompt_text = build_prompt_text

        # Get the image data
        image_data = get_image_data
        unless image_data
          fail_with_error("No image provided for video generation")
          return
        end

        # Make the API request
        response = make_api_request(prompt_text, image_data)
        unless response
          fail_with_error("API request failed", {})
          return
        end

        # Process the response (response is already parsed data from polling)
        process_response(response)
      rescue => e
        Rails.logger.error("Gemini video generation failed: #{e.message}")
        fail_with_error("Video generation failed: #{e.message}")
      end

      def build_prompt_text
        # Combine system prompt and user message
        base_text = if prompt_run.prompt.system_prompt.present?
          "#{prompt_run.prompt.system_prompt}\n\n#{prompt_run.run.message}"
        else
          prompt_run.run.message
        end

        # Apply template variables if present
        if prompt_run.run.variables.present?
          Mustache.render(base_text, prompt_run.run.variables.deep_symbolize_keys)
        else
          base_text
        end
      end

      def get_image_data
        attachment = get_first_image_attachment
        return nil unless attachment

        attachment.blob.open do |file|
          {
            data: Base64.strict_encode64(file.read),
            mime_type: Marcel::MimeType.for(file)
          }
        end
      end

      def get_first_image_attachment
        # check for first source image attachment
        return prompt_run.source_attachments.first if prompt_run.source_attachments.any?

        # Check run's subject image first
        return prompt_run.run.subject_image if prompt_run.run.subject_image.attached?

        # Check prompt's subject image
        return prompt.subject_image if prompt.subject_image.attached?

        # Check other attachments
        all_attachments = [ *prompt_run.run.attachments, *prompt.attachments ]
        all_attachments.find { |att| att.blob.content_type&.start_with?("image/") }
      end

      def make_api_request(prompt_text, image_data)
        model = resolve_model_name
        project_id = google_cloud_project_id

        # Use Vertex AI format for video generation
        request_body = {
          instances: [
            {
              prompt: prompt_text,
              image: {
                bytesBase64Encoded: image_data[:data],
                mimeType: image_data[:mime_type]
              }
            }
          ],
          parameters: {
            sampleCount: 1,
            durationSeconds: 4,
            generateAudio: false
          }
        }

        # Use Vertex AI predictLongRunning endpoint
        response = self.class.post(
          "/v1/projects/#{project_id}/locations/us-central1/publishers/google/models/#{model}:predictLongRunning",
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Content-Type" => "application/json"
          },
          body: request_body.to_json
        )

        # If this is a long-running operation, poll for completion
        if response&.success? && response.parsed_response["name"]
          poll_vertex_operation(response.parsed_response["name"])
        else
          response
        end
      end

      def poll_vertex_operation(operation_name)
        max_attempts = 60 # 10 minutes with 10s intervals
        attempts = 0
        project_id = google_cloud_project_id
        model = resolve_model_name

        while attempts < max_attempts
          # Use Vertex AI fetchPredictOperation endpoint
          response = self.class.post(
            "/v1/projects/#{project_id}/locations/us-central1/publishers/google/models/#{model}:fetchPredictOperation",
            headers: {
              "Authorization" => "Bearer #{access_token}",
              "Content-Type" => "application/json"
            },
            body: { operationName: operation_name }.to_json
          )

          if response&.success?
            result = response.parsed_response
            return result if result["done"]
          end

          sleep 10
          attempts += 1
        end

        # Return the last response even if not done
        response&.parsed_response
      end

      def process_response(response_data)
        # Check if we have video data in the response
        video_data = extract_video_data(response_data)

        if video_data.blank?
          fail_with_error("No video data in response", response_data)
          return
        end

        # Process and attach the video
        attach_video_from_data(video_data)

        # Update with success
        prompt_run.update!(
          response: {
            body: sanitize_response(response_data),
            status: "completed",
            error: nil
          }
        )
        prompt_run.update_with_status!("completed")
      end

      def extract_video_data(response_data)
        # For Vertex AI response format
        if response_data["response"]
          # Check for videos array in Vertex AI format
          videos = response_data.dig("response", "videos")
          if videos&.any?
            video = videos.first
            # Return base64 encoded video data or gcsUri
            return {
              type: "base64",
              data: video["bytesBase64Encoded"],
              mime_type: video["mimeType"] || "video/mp4"
            } if video["bytesBase64Encoded"]

            return {
              type: "url",
              data: video["gcsUri"],
              mime_type: video["mimeType"] || "video/mp4"
            } if video["gcsUri"]
          end
        end

        nil
      end

      def attach_video_from_data(video_data)
        filename = "veo_generated_#{Time.current.to_i}.mp4"

        case video_data[:type]
        when "base64"
          # Decode base64 data and create a temporary file
          decoded_data = Base64.decode64(video_data[:data])
          temp_file = Tempfile.new([ "video", ".mp4" ])
          temp_file.binmode
          temp_file.write(decoded_data)
          temp_file.rewind

          prompt_run.attachments.attach(
            io: temp_file,
            filename: filename,
            content_type: video_data[:mime_type]
          )

          temp_file.close
          temp_file.unlink

        when "url"
          # Download from URL (GCS or other)
          video_url = video_data[:data]
          if video_url.start_with?("gs://")
            # For GCS URLs, convert to HTTPS and use authenticated requests
            file = URI.open(
              video_url.gsub("gs://", "https://storage.googleapis.com/"),
              "Authorization" => "Bearer #{access_token}"
            )
          else
            # For other URLs
            file = URI.open(video_url, "Authorization" => "Bearer #{access_token}")
          end

          prompt_run.attachments.attach(
            io: file,
            filename: filename,
            content_type: video_data[:mime_type]
          )
        end
      end

      def resolve_model_name
        model = prompt_run.prompt.selected_model.presence || "veo-3"

        case model.to_s.downcase
        when "veo-3", "veo-3.0"
          "veo-3.0-generate-preview"
        when "veo-3-fast"
          "veo-3.0-fast-generate-preview"
        else
          model
        end
      end

      def sanitize_response(response_data)
        # Remove sensitive data from response before storing
        sanitized = response_data.deep_dup

        # Handle Vertex AI response format
        if sanitized["response"]
          # Sanitize video data in Vertex AI format
          videos = sanitized.dig("response", "videos")
          if videos&.any?
            videos.each do |video|
              video["gcsUri"] = "<downloaded>" if video["gcsUri"]
              video["bytesBase64Encoded"] = "<downloaded>" if video["bytesBase64Encoded"]
            end
          end

          # Sanitize other possible video URI formats
          if sanitized.dig("response", "generateVideoResponse", "generatedSamples", 0, "video", "uri")
            sanitized["response"]["generateVideoResponse"]["generatedSamples"][0]["video"]["uri"] = "<downloaded>"
          end
          if sanitized.dig("response", "generatedVideos", 0, "video", "uri")
            sanitized["response"]["generatedVideos"][0]["video"]["uri"] = "<downloaded>"
          end
          if sanitized.dig("response", "video", "uri")
            sanitized["response"]["video"]["uri"] = "<downloaded>"
          end
        end

        sanitized
      end

      def fail_with_error(message, response_data = nil)
        prompt_run.update!(
          response: {
            body: response_data || {},
            status: "failed",
            error: message
          }
        )
        prompt_run.update_with_status!("failed")
      end

      def access_token
        # Get OAuth2 access token for Vertex AI
        # This assumes you have service account credentials configured
        Rails.application.credentials.google_cloud_access_token ||
        ENV["GOOGLE_CLOUD_ACCESS_TOKEN"] ||
        generate_access_token
      end

      def google_cloud_project_id
        Rails.application.credentials.dig(:google_cloud, :project_id) ||
        Rails.application.credentials.google_cloud_project_id ||
        ENV["GOOGLE_CLOUD_PROJECT_ID"] ||
        ENV["GOOGLE_CLOUD_PROJECT"]
      end

      def gemini_api_key
        Rails.application.credentials.gemini_api_key || ENV["GEMINI_API_KEY"]
      end

      private

      def generate_access_token
        require "googleauth"
        require "stringio"

        # Try to use service account key from Rails credentials first
        service_account_key = Rails.application.credentials.dig(:google_cloud, :service_account_key)

        if service_account_key
          # Parse the service account key if it's a string
          key_data = service_account_key.is_a?(String) ? JSON.parse(service_account_key) : service_account_key

          # Create authorizer from service account key
          scopes = [ "https://www.googleapis.com/auth/cloud-platform" ]
          authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
            json_key_io: StringIO.new(key_data.to_json),
            scope: scopes
          )
          authorizer.fetch_access_token!["access_token"]
        else
          # Fall back to application default credentials
          scopes = [ "https://www.googleapis.com/auth/cloud-platform" ]
          authorizer = Google::Auth.get_application_default(scopes)
          authorizer.fetch_access_token!["access_token"]
        end
      rescue => e
        Rails.logger.error("Failed to generate access token: #{e.message}")
        Rails.logger.error("Make sure your service account key is properly configured in Rails credentials")
        nil
      end
    end
  end
end
