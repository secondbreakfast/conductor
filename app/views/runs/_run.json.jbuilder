json.extract! run, :id, :flow_id, :status, :started_at, :completed_at, :created_at, :updated_at
json.data run.data
json.url run_url(run, format: :json)
