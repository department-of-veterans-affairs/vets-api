# frozen_string_literal: true

# Enable AWS SDK stubbing in development when explicitly requested.
# This avoids hitting real AWS endpoints during local uploads.
Aws.config.update(stub_responses: true) if Rails.env.development? && ENV['AWS_STUB'] == 'true'
