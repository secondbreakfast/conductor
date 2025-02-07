json.extract! prompt, :id, :background_prompt, :light_source_direction, :light_source_strength, :foreground_prompt, :negative_prompt, :preserve_original_subject, :original_background_depth, :keep_original_background, :seed, :output_format, :flow_id, :created_at, :updated_at
json.url prompt_url(prompt, format: :json)
