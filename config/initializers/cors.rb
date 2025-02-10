Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # This allows requests from any origin
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['Authorization']  # Expose any custom headers you might need
  end
end 