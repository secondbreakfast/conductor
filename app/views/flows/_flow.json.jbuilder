json.extract! flow, :id, :name, :description, :created_at, :updated_at
json.url flow_url(flow, format: :json)
json.prompts flow.prompts do |prompt|
  json.id prompt.id
  json.endpoint_type prompt.endpoint_type
  json.selected_provider prompt.selected_provider
  json.selected_model prompt.selected_model
end
