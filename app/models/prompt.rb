class Prompt < ApplicationRecord
  belongs_to :flow

  # deprecate these
  has_one_attached :subject_image
  has_one_attached :background_reference

  has_many_attached :attachments

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

  # model options
  def self.model_options
    {
      chat: {
        openai: {
          models: [ "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini", "gpt-4o-2024-08-06" ]
        },
        anthropic: {
          models: [ "claude-3-5-sonnet-20240620", "claude-3-7-sonnet" ]
        }
      },
      image_to_image: {
        openai: {
          models: [ "gpt-image-1", "dall-e-3", "dall-e-2" ]
        },
        gemini: {
          models: [ "gemini-2.5-flash-image-preview" ]
        },
        stability: {
          models: [ "replace_background_and_relight" ]
        }
      }
    }
  end
end
