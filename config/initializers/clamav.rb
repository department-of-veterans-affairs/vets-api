# frozen_string_literal: true

if Rails.env.development?
  ENV['CLAMD_TCP_HOST'] = Settings.clamav.host
  ENV['CLAMD_TCP_PORT'] = Settings.clamav.port
end
