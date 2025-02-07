class Prompt < ApplicationRecord
  belongs_to :flow
  has_one_attached :subject_image
  has_one_attached :background_reference
end
