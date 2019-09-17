# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flipper UI', type: :request do
  it 'Displays list of features' do
    get '/flipper/features', params: nil, headers: { 'HTTP_AUTHORIZATION':
          ActionController::HttpAuthentication::Basic.encode_credentials(
            Settings.flipper.username,
            Settings.flipper.password
          ) }

    assert_response :success
  end
end
