# frozen_string_literal: true

require 'rails_helper'
require_relative '../swagger/claims_api/rswag_config'

RSpec.configure do |config|
  ClaimsApi::RswagConfig.new.configure(config: config)
end
