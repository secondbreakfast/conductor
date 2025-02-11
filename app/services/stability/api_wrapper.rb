module Stability
  class ApiWrapper
    include HTTParty
    base_uri "https://api.stability.ai/v2beta"

    POLLING_INTERVAL = 5 # seconds
    TIMEOUT = 500 # seconds

    def initialize
      @api_key = Rails.application.credentials.stability_api_key
    end

    def replace_background_and_relight(
      image,
      background_prompt: nil,
      background_reference: nil,
      preserve_original_subject: 0.8,
      original_background_depth: 0.65,
      output_format: "webp"
    )
      # Validate that either background_prompt or background_reference is provided
      if background_prompt.blank? && background_reference.blank?
        raise ArgumentError, "Either background_prompt or background_reference must be provided"
      end

      # Convert ActiveStorage blob to tempfile
      tempfile = create_tempfile_from_blob(image)
      background_tempfile = background_reference.present? ? create_tempfile_from_blob(background_reference) : nil

      # Create form data
      payload = {
        subject_image: File.open(tempfile.path),
        output_format: output_format,
        preserve_original_subject: preserve_original_subject,
        original_background_depth: original_background_depth
      }

      # Add either background_prompt or background_reference to payload
      if background_reference.present?
        payload[:background_reference] = File.open(background_tempfile.path)
      else
        payload[:background_prompt] = background_prompt
      end

      puts "Payload: #{payload}"

      # Initial API call
      response = self.class.post(
        "/stable-image/edit/replace-background-and-relight",
        headers: auth_headers,
        multipart: true,
        body: payload
      )
      puts "Response: #{response}"
      response
    ensure
      tempfile&.close
      tempfile&.unlink
      background_tempfile&.close
      background_tempfile&.unlink
    end

    def get_generation(generation_id)
      puts "Polling results for generation ID: #{generation_id}"
      result = poll(generation_id)
      puts "Poll response status: #{result.code}"
      if result.code == 200
        process_result(result)
      end
    end

    def poll(generation_id)
      poll_result(generation_id)
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
