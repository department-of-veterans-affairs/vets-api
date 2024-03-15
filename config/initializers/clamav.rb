# frozen_string_literal: true

if Rails.env.development?
  ENV["CLAMD_TCP_HOST"] = Settings.clamav.host || 'clamav'
  ENV["CLAMD_TCP_PORT"] = Settings.clamav.port || '3310'
end
