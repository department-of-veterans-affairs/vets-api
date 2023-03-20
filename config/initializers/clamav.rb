if Rails.env.development?
  ENV["CLAMD_TCP_HOST"] = "127.0.0.1"
  ENV["CLAMD_TCP_PORT"] = "3310"
end
