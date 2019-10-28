# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flipper UI', type: :request do
  context '#logged in ' do
    let(:user) { build(:user, :loa3) }
    let(:token) { Rack::Protection::AuthenticityToken.random_token }
    let(:session) do
      { :csrf => token, 'csrf' => token, '_csrf_token' => token }
    end

    before do
      sign_in_as(user)
    end

    it 'Displays list of features' do
      get '/flipper/features', params: nil
      assert_response :success
    end

    it 'records the admin user when a toggle value is chaged' do
      Flipper.enable('mvi_id_parser')
      post '/flipper/features/mvi_id_parser/boolean',
           params: { 'action' => 'Enable', 'authenticity_token' => token },
           session: { 'rack.session' => session }
      assert_response :redirect
      expect(FeatureToggleEvent.last.user).to eq(user.email)
    end
  end

  context '#not logged in ' do
    it 'no Displays list of features' do
      get '/flipper/features', params: nil
      assert_response :missing
    end
  end
end
