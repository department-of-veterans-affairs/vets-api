# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flipper UI' do
  def bypass_flipper_authenticity_token
    Rails.application.routes.draw do
      mount Flipper::UI.app(
        Flipper.instance,
        rack_protection: { except: :authenticity_token }
      ) => '/flipper', constraints: Flipper::AdminUserConstraint.new
    end
    yield
    Rails.application.reload_routes!
  end

  context 'with authenticated admin user' do
    before do
      sign_in_as(user)
      allow(Settings.flipper).to receive(:admin_user_emails).and_return(user.email)
      Flipper.enable(:test_feature)
    end

    context 'with LOA1 access' do
      let(:user) { build(:user) }

      it 'does not allow feature toggling' do
        post '/flipper/features/test_feature/boolean', params: nil
        assert_response :not_found
        expect(JSON.parse(response.body)['errors'][0]['detail']).to include('There are no routes matching your request')
      end
    end

    context 'with LOA3 access' do
      let(:user) { build(:user, :loa3) }

      it 'Displays list of features' do
        get '/flipper/features', params: nil
        expect(response.body).to include('flipper/features')
        assert_response :success
      end

      it 'Allows user to toggle feature' do
        bypass_flipper_authenticity_token do
          expect(Flipper.enabled?(:test_feature)).to be true
          post '/flipper/features/test_feature/boolean', params: nil
          assert_response :found
          expect(Flipper.enabled?(:test_feature)).to be false
        end
      end
    end
  end

  context 'when unauthenticated' do
    it 'feature route is read only' do
      get '/flipper/features', params: nil
      assert_response :success
      expect(response.body).not_to include('flipper/features')
    end

    it 'does not allow feature toggles' do
      bypass_flipper_authenticity_token do
        Flipper.enable(:test_feature)
        expect do
          post '/flipper/features/test_feature/boolean', params: nil
        end.to raise_error(ActionController::RoutingError)
      end
    end
  end
end
