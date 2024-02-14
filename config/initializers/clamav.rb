# frozen_string_literal: true

if Rails.env.development?
  ENV['CLAMD_TCP_HOST'] = '0.0.0.0'
  ENV['CLAMD_TCP_PORT'] = '33100'
end
