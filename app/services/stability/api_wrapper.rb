module Stability
  class ApiWrapper
    include HTTParty
    base_uri "https://api.stability.ai/v2beta"

    POLLING_INTERVAL = 5 # seconds
    TIMEOUT = 500 # seconds

    def initialize
      @api_key = Rails.application.credentials.stability_api_key
    end

    def replace_background_and_relight(image, background_prompt:, preserve_original_subject: 0.7, original_background_depth: 0.25, output_format: "webp")
      # Convert ActiveStorage blob to tempfile
      tempfile = create_tempfile_from_blob(image)

      # Create form data
      payload = {
        subject_image: File.open(tempfile.path),
        background_prompt: background_prompt,
        output_format: output_format,
        preserve_original_subject: preserve_original_subject,
        original_background_depth: original_background_depth
      }

      # Initial API call
      response = self.class.post(
        "/stable-image/edit/replace-background-and-relight",
        headers: auth_headers,
        multipart: true,
        body: payload
      )

      raise ApiError, response.body unless response.success?

      generation_id = response["id"]

      # Poll for results
      start_time = Time.current
      loop do
        puts "Polling results for generation ID: #{generation_id}"
        result = poll_result(generation_id)
        puts "Poll response status: #{result.code}"

        return process_result(result) unless result.code == 202

        raise TimeoutError if Time.current - start_time > TIMEOUT

        puts "Waiting #{POLLING_INTERVAL} seconds before next poll..."
        sleep POLLING_INTERVAL
      end
    ensure
      tempfile&.close
      tempfile&.unlink
    end

    private

    def create_tempfile_from_blob(blob)
      tempfile = Tempfile.new([ "image", ".#{blob.filename.extension}" ])
      tempfile.binmode
      blob.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind
      tempfile
    end

    def auth_headers
      {
        "Authorization" => "Bearer #{@api_key}"
      }
    end

    def poll_result(generation_id)
      self.class.get(
        "/results/#{generation_id}",
        headers: auth_headers
      )
    end

    def process_result(response)
      raise ApiError, response.body unless response.success?

      # Check for NSFW classification
      if response.headers["finish-reason"] == "CONTENT_FILTERED"
        raise ApiError, "Generation failed NSFW classifier"
      end

      # Get the seed from headers for filename
      seed = response.headers["seed"]

      # Generate a random filename with seed
      random_suffix = SecureRandom.hex(8)
      filename = "stability_output_#{seed}_#{random_suffix}.webp"

      # Create a blob directly from the response content
      # run.attachments.create!(blob: result)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(response.body),
        filename: filename,
        content_type: "image/webp"
      )
    end
  end

  class ApiError < StandardError; end
  class TimeoutError < StandardError; end
end
