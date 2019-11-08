# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flipper UI', type: :request do
  before(:all) do
    Rails.application.routes.draw do
      mount Flipper::UI.app(
        Flipper.instance,
        rack_protection: { except: :authenticity_token }
      ) => '/flipper', constraints: Flipper::AdminUserConstraint.new
    end
  end

  after(:all) { Rails.application.reload_routes! }

  context 'when authenticated with LOA3 admin user' do
    let(:user) { build(:user, :loa3) }

    before do
      sign_in_as(user)
      Settings.flipper.admin_user_emails << user.email
    end

    it 'Displays list of features' do
      get '/flipper/features', params: nil
      expect(response.body).to include('flipper/features')
      assert_response :success
    end

    it 'Allows user to toggle feature' do
      Flipper.enable(:test_feature)
      expect(Flipper.enabled?(:test_feature)).to be true
      post '/flipper/features/test_feature/boolean', params: nil
      assert_response :found
      expect(Flipper.enabled?(:test_feature)).to be false
    end
  end

  context 'when unauthenticted' do
    it 'feature route is read only' do
      get '/flipper/features', params: nil
      assert_response :success
      expect(response.body).not_to include('flipper/features')
    end

    it 'does not allow feature toggles' do
      Flipper.enable(:test_feature)
      expect do
        post '/flipper/features/test_feature/boolean', params: nil
      end.to raise_error(ActionController::RoutingError)
    end
  end
end
