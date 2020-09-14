# frozen_string_literal: true

require_relative 'support/iam_session_helper'

RSpec.configure do |config|
  config.include IAMSessionHelper, type: :controller
  config.include IAMSessionHelper, type: :request

  config.before :each, type: :request do
    Flipper.enable('mobile_api')
    stub_certs
  end

  config.before :each, type: :controller do
    Flipper.enable('mobile_api')
    stub_certs
  end
end
