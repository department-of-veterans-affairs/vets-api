# frozen_string_literal: true

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
