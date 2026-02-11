# frozen_string_literal: true

require 'spec_helper'
require 'support/factory_bot'
require_relative 'support/auth_helper'
require_relative 'support/mock_bgs_file_number_check'
require_relative 'support/stub_claims_api_auth_token'
require_relative 'support/bgs_client_spec_helpers'
require 'bd/bd'
require 'evss_service/base'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
