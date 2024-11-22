begin
  config = YAML.load(
    ERB.new(
      File.read(
        File.expand_path('../database.yml', __dir__)
      )
    ).result
  )[Rails.env]

  ActiveRecord::Base.establish_connection(config)
rescue StandardError => e
  warn "Failed to connect to database: #{e.message}"
  exit 1
end 