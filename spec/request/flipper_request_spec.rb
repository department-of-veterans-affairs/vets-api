# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flipper UI', type: :request do
  context 'Authenticated with LOA3 admin user' do
    let(:user) { build(:user, :loa3) }

    before do
      sign_in_as(user)
    end

    it 'Displays list of features' do
      get '/flipper/features', params: nil
      assert_response :success
    end
  end

  context 'Unautenticted' do
    it 'feature route is unavailable' do
      get '/flipper/features', params: nil
      assert_response :missing
    end
  end
end
