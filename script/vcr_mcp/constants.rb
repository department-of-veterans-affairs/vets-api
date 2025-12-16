# frozen_string_literal: true

module VcrMcp
  # Shared constants for VCR MCP tools
  module Constants
    # Root path of the vets-api repository
    VETS_API_ROOT = File.expand_path('../..', __dir__)

    # VCR cassette directory
    CASSETTE_ROOT = File.join(VETS_API_ROOT, 'spec', 'support', 'vcr_cassettes')

    # AWS region (configurable via environment variable)
    AWS_REGION = ENV.fetch('AWS_REGION', 'us-gov-west-1')
  end
end
