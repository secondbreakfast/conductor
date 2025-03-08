class Prompt < ApplicationRecord
  belongs_to :flow

  # deprecate these
  has_one_attached :subject_image
  has_one_attached :background_reference

  # endpoint_type:  Chat | ImageToImage | ImageToVideo | AudioToText | TextToAudio
  # selected_provider: OpenAI | Stability | Replicate | Anthropic
  # selected_model
  # 
end
