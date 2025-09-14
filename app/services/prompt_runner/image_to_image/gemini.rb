module PromptRunner
  module ImageToImage
    class Gemini < Runner
      require "open-uri"
      require "tempfile"
      require "base64"
      require "json"
      include HTTParty

      base_uri "https://generativelanguage.googleapis.com"

      def run
        create_image
      end

      def create_image
        prompt_text = render_template(prompt_run.prompt.system_prompt.present? ? "#{prompt_run.prompt.system_prompt}\n\n#{prompt_run.run.message}" : prompt_run.run.message)
        model = prompt_run.prompt.selected_model.presence || "gemini-2.5-flash-image-preview"

        contents = build_contents(prompt_text)

        response = self.class.post(
          "/v1beta/models/#{model}:generateContent",
          headers: {
            "x-goog-api-key" => gemini_api_key,
            "Content-Type" => "application/json"
          },
          body: { contents: contents }.to_json
        )

        handle_response(response)
      rescue => e
        Rails.logger.error("Gemini image generation failed: #{e.message}")
        prompt_run.update_with_status!("failed")
      end

      def handle_response(response)
        unless response&.success?
          prompt_run.update!(response: { body: safe_json(response), status: "failed", error: response&.parsed_response })
          prompt_run.update_with_status!("failed")
          return
        end

        parts = dig_candidate_parts(response.parsed_response)
        if parts.blank?
          prompt_run.update!(response: { body: response.parsed_response, status: "failed", error: "No content parts returned" })
          prompt_run.update_with_status!("failed")
          return
        end

        attached_any = false
        sanitized_parts = []

        parts.each_with_index do |part, index|
          if part["inlineData"]&.dig("data").present?
            data = part["inlineData"]["data"]
            mime = part["inlineData"]["mimeType"] || "image/png"
            io = StringIO.new(Base64.decode64(data), "rb")
            ext = mime.split("/").last
            filename = "gemini_generated_#{index + 1}.#{ext}"
            prompt_run.attachments.attach(io: io, filename: filename, content_type: mime)
            sanitized_parts << part.except("inlineData").merge("inlineData" => { "mimeType" => mime, "data" => "<omitted>" })
            attached_any = true
          elsif part["text"].present?
            sanitized_parts << part
          end
        end

        body = response.parsed_response.deep_dup
        if body["candidates"]&.first&.dig("content", "parts").present?
          body["candidates"][0]["content"]["parts"] = sanitized_parts
        end

        status = attached_any ? "completed" : "failed"
        prompt_run.update!(response: { body: body, status: status, error: nil })
        prompt_run.update_with_status!(status)
      rescue => e
        Rails.logger.error("Gemini response handling error: #{e.message}")
        prompt_run.update_with_status!("failed")
      end

      def build_contents(prompt_text)
        parts = [ { "text" => prompt_text } ]

        if input_attachments.any?
          with_open_blobs(input_attachments) do |files|
            files.each do |file|
              mime = Marcel::MimeType.for(file)
              base64 = Base64.strict_encode64(file.read)
              parts << { "inlineData" => { "mimeType" => mime, "data" => base64 } }
            end
          end
        end

        [ { "parts" => parts } ]
      end

      def dig_candidate_parts(parsed)
        parsed&.dig("candidates", 0, "content", "parts")
      end

      def safe_json(httparty_response)
        httparty_response&.parsed_response || httparty_response&.body
      end

      def gemini_api_key
        Rails.application.credentials.gemini_api_key || ENV["GEMINI_API_KEY"]
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
          yield opened_files
        else
          attachment = remaining_attachments.first
          attachment.blob.open do |file|
            open_first_blob(remaining_attachments[1..-1], opened_files + [ file ], &block)
          end
        end
      end

      def render_template(template)
        return template unless prompt_run.run.variables.present?
        Mustache.render(template, prompt_run.run.variables.deep_symbolize_keys)
      end
    end
  end
end
