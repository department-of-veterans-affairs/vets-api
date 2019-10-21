# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/LineLength
RSpec.describe 'vaos appointments', type: :request do
  include SchemaMatchers

  before do
    sign_in_as(current_user)
  end

  context 'loa1 user' do
    let(:current_user) { build(:user, :loa1) }

    it 'should not have access' do
      get '/services/vaos/v0/appointments'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'loa3 user with flipper disabled' do
    let(:current_user) { build(:user, :dslogon) }

    it 'should not have access' do
      allow(Flipper).to receive(:enabled?).and_return(false)
      get '/services/vaos/v0/appointments'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'loa3 user' do
    let(:current_user) { build(:user, :dslogon) }

    # skipping this spec for now
    xit 'should have access' do
      allow(Flipper).to receive(:enabled?).and_return(true)
      get '/services/vaos/v0/appointments'
      expect(response).to have_http_status(:success)
    end
  end
end
