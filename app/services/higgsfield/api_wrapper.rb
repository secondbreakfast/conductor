module Higgsfield
  class ApiWrapper
    include HTTParty
    base_uri "https://api.higgsfield.dev"

    POLLING_INTERVAL = 5 # seconds
    TIMEOUT = 500 # seconds

    def initialize
      @api_key = Rails.application.credentials.higgsfield_api_key
      @secret = Rails.application.credentials.higgsfield_secret
    end

    def create_video(
      image,
      prompt: nil,
      model: "dop-lite",
      seed: 1,
      motions: [
        { id: "81ca2cd2-05db-4222-9ba0-a32e5185adfb", strength: 1 }, # Dolly In
        { id: "40245735-2670-4572-b46e-854151281f55", strength: 1 } # Overhead (drifts)
        # { id: "b26dcbe5-e784-4893-b8a3-2bd4f848e90a", strength: 1 }, # Crane Down
        # { id: "a85cb3f2-f2be-4ee2-b3b9-808fc6a81acc", strength: 1 }, # Arc Right
        # { id: "fbcbec5b-30f8-4b17-ba6e-8e8d5b265562", strength: 1 }, # Zoom In
        # { id: "263600e4-45c0-4c13-9579-40a9278af37c", strength: 1 }  # Zoom Out
      ],
      enhance_prompt: true,
      check_nsfw: true
    )
      # Convert ActiveStorage blob to image URL (assuming you have a way to get public URLs)
      # For now, we'll assume you have a method to get a public URL from the blob
      image_url = "https://storage.googleapis.com/neutrals-production/jz68db3f87m5x5sjt257db52iiky?GoogleAccessId=neutrals-rails-production%40neutrals-436007.iam.gserviceaccount.com&Expires=1753910935&Signature=Svrl3j0%2BxLN8JGCaWv27qxfYY0B8Lxq18vvJV9A0Leg0eNc9tGx5VW5ptSkVIwl35mr%2FXqZN9m3cRaRroQaL6oAbvQpFjXMW6Sk4doIPDhYIA6xvo3xx50CRe764Zg9F95P5VEfA1A1yKDynCyvdfRf0AucgsI2HHX%2BN33OACGwEXQyRFgF19uYb0IsjNTOTu%2BQP62nL9FnltCpARGTcz2221iqLf5Xe7jh0uW2S9Wb56XMyHyUe7lAmptyjQHoXAWaicStoo7BJMlyo6GSlid1HpnUGB3gEh8c2Rgy17sUO67p%2FvHJZ%2BasFbJ063SI%2B%2BsyDFGfGqRrksrjOKcZd%2Bg%3D%3D&response-content-disposition=inline%3B+filename%3D%22input_attachment.jpg%22%3B+filename%2A%3DUTF-8%27%27input_attachment.jpg&response-content-type=image%2Fjpeg" # get_public_url_for_blob(image)

      # Create payload
      payload = {
        params: {
          model: model,
          prompt: prompt,
          seed: seed,
          motions: motions,
          input_images: [
            {
              type: "image_url",
              image_url: image_url
            }
          ],
          enhance_prompt: enhance_prompt,
          check_nsfw: check_nsfw
        }
      }

      puts "Payload: #{payload}"

      # Initial API call
      response = self.class.post(
        "/v1/job-sets",
        headers: auth_headers,
        body: payload.to_json
      )

      puts "Response: #{response}"
      response
    end

    def get_job_status(job_set_id)
      puts "Getting job status for ID: #{job_set_id}"
      result = self.class.get(
        "/v1/job-sets/#{job_set_id}",
        headers: auth_headers
      )
      puts "Job status response: #{result.code}"
      result
    end

    def get_generation(job_set_id)
      puts "Polling results for job set ID: #{job_set_id}"
      result = poll(job_set_id)
      puts "Poll response status: #{result.code}"
      if result.code == 200
        process_result(result)
      end
    end

    def poll(job_set_id)
      poll_result(job_set_id)
    end

    def list_motions
      puts "Fetching available motions"
      response = self.class.get(
        "/v1/motions",
        headers: auth_headers
      )
      puts "Motions response status: #{response.code}"
      if response.success?
        begin
          # Try to parse as JSON first
          parsed_body = JSON.parse(response.body)
          puts "Motions response: #{parsed_body}"
        rescue JSON::ParserError
          # If not JSON, handle encoding issues
          safe_body = response.body.force_encoding("UTF-8").scrub("?")
          puts "Motions response body: #{safe_body}"
        end
      end
      response
    end

    def health_check
      response = self.class.get("/health")
      puts "Health check response: #{response}"
      response
    end

    private

    def get_public_url_for_blob(blob)
      # This is a placeholder - you'll need to implement this based on your setup
      # Options:
      # 1. If using cloud storage (S3, etc.), generate a signed URL
      # 2. If serving locally, create a public URL through your Rails app
      # 3. Upload to a temporary public location

      # For now, assuming you have Rails.application.routes.url_helpers available
      # and your blob is publicly accessible:
      Rails.application.routes.url_helpers.rails_blob_url(blob, host: Rails.application.config.action_mailer.default_url_options[:host])
    end

    def auth_headers
      {
        "Content-Type" => "application/json",
        "hf-api-key" => @api_key,
        "hf-secret" => @secret
      }
    end

    def poll_result(job_set_id)
      self.class.get(
        "/v1/job-sets/#{job_set_id}",
        headers: auth_headers
      )
    end

    def process_result(response)
      raise ApiError, response.body unless response.success?

      # Parse the JSON response
      result_data = JSON.parse(response.body)

      # Extract video URL or data from the response
      # This will depend on the actual response format from Higgsfield
      # You'll need to adjust this based on the actual API response structure
      if result_data["status"] == "completed" && result_data["output_url"]
        download_and_store_video(result_data["output_url"])
      else
        raise ApiError, "Generation not completed or no output URL found"
      end
    end

    def download_and_store_video(video_url)
      # Download the video from the URL and create an ActiveStorage blob
      response = HTTParty.get(video_url)
      raise ApiError, "Failed to download video" unless response.success?

      random_suffix = SecureRandom.hex(8)
      filename = "higgsfield_video_#{random_suffix}.mp4"

      # Create a blob directly from the response content
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(response.body),
        filename: filename,
        content_type: "video/mp4"
      )
    end
  end

  class ApiError < StandardError; end
  class TimeoutError < StandardError; end
end
