# frozen_string_literal: true

if Rails.env.development?
  ENV['CLAMD_TCP_HOST'] = 'clamav'
  ENV['CLAMD_TCP_PORT'] = '3310'
end
