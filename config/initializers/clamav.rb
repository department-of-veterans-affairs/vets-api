# frozen_string_literal: true

## If running clamav natively
# ENV['CLAMD_UNIX_SOCKET'] = '/usr/local/etc/clamav/clamd.sock'

## Comment the following out (everything below) if you are running clamav natively

## If running via docker
if Rails.env.development?
  ENV['CLAMD_TCP_HOST'] = 'clamav'
  ENV['CLAMD_TCP_PORT'] = '3310'
end

# ## If running hybrid
# if Rails.env.development?
#   ENV["CLAMD_TCP_HOST"] = "0.0.0.0"
#   ENV["CLAMD_TCP_PORT"] = "33100"
# end
