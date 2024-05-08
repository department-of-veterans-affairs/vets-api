# frozen_string_literal: true

if Rails.env.development?
  # If running ClamAV through container
  # Update host and port on settings.local.yml to override the socket
  ENV['CLAMD_TCP_HOST'] = Settings.clamav.host
  ENV['CLAMD_TCP_PORT'] = Settings.clamav.port

  # If running ClamAV natively (via daemon)
  # Uncomment this line if running with daemon
  # Remove clamav host and port on settings.local.yml to override the tcp connection
  # ENV['CLAMD_UNIX_SOCKET'] = '/usr/local/etc/clamav/clamd.sock'
end
