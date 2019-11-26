# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'preferences', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1) }

    it 'returns a forbidden error' do
      get '/v0/vaos/preferences'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'with a loa3 user' do
    let(:user) { build(:user, :mhv) }

    context 'with a valid GET preferences response' do
      it 'returns a 200 with the correct schema' do
        VCR.use_cassette('vaos/preferences/get_preferences', match_requests_on: %i[method uri]) do
          get '/v0/vaos/preferences'

          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('vaos/preferences')
        end
      end
    end
  end
end
