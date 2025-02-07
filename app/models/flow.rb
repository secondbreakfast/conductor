class Flow < ApplicationRecord
  has_many :runs
  has_many :prompts
end
