# frozen_string_literal: true

# Shared context to stub the UHD API Gateway security endpoint Flipper flag.
#
# All Flipper flags defined in config/features.yml are auto-enabled in the test environment.
# VCR cassettes for UHD were recorded against the legacy security endpoint
# (security_host/mhvapi/security/v1/login), so tests that replay those cassettes need
# this flag disabled to avoid URL mismatches.
#
# Usage:
#   include_context 'uhd legacy security endpoint'
#
RSpec.shared_context 'uhd legacy security endpoint' do
  before do
    allow(Flipper).to receive(:enabled?)
      .with(:mhv_uhd_api_gateway_security_endpoint)
      .and_return(false)
  end
end
