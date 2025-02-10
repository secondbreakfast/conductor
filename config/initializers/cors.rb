Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"  # This allows requests from any origin
    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization" ],
      credentials: true,
      max_age: 3600
  end
end
