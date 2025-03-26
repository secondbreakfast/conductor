class Prompt < ApplicationRecord
  belongs_to :flow

  # deprecate these
  has_one_attached :subject_image
  has_one_attached :background_reference

  # endpoint_type:  Chat | ImageToImage | ImageToVideo | AudioToText | TextToAudio
  # selected_provider: OpenAI | Stability | Replicate | Anthropic
  # selected_model
  #

  # Handle JSON conversion for tools field
  def tools=(value)
    # If the value is a string (from form input), parse it as JSON
    if value.is_a?(String)
      begin
        parsed_value = value.present? ? JSON.parse(value) : nil
        super(parsed_value)
      rescue JSON::ParserError => e
        errors.add(:tools, "is not valid JSON: #{e.message}")
        super(nil)
      end
    else
      # If it's already a hash/array (from API or programmatic assignment), use it directly
      super(value)
    end
  end
end
