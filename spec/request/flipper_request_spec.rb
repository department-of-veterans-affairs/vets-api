# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flipper UI', type: :request do
  context '#logged in ' do
    let(:user) { build(:user, :loa3) }

    before do
      sign_in_as(user)
    end

    it 'Displays list of features' do
      get '/flipper/features', params: nil
      assert_response :success
    end
  end

  context '#not logged in ' do
    it 'no Displays list of features' do
      get '/flipper/features', params: nil
      assert_response :missing
    end
  end
end
