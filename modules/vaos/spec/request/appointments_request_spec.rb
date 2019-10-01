# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS appointments', type: :request do
  include SchemaMatchers

  before(:each) { sign_in_as(user) }

  context 'with a loa1 user' do
    let(:user) { create(:user, :loa1) }

    it 'returns a forbidden error' do
      get '/vaos/v0/appointments'
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user' do
    let(:user) { create(:user, :mhv) }

    it 'returns a successful response' do
      VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[host path method]) do
        get '/vaos/v0/appointments'
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
