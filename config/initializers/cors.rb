Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "http://localhost:3000",
            "http://localhost:3010",
            "http://localhost:8080",
            "https://dashboard.owner.com",
            "https://conductor-production-662c.up.railway.app",
            "https://dev-grader.owner.com",
            "https://grader.owner.com"

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization" ],
      credentials: true,
      max_age: 3600
  end
end
