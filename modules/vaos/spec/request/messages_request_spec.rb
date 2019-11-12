# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'vaos appointment request messages', type: :request do
  include SchemaMatchers

  let(:rsa_private) { OpenSSL::PKey::RSA.generate 4096 }

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'loa1 user with flipper enabled' do
    let(:current_user) { build(:user, :loa1) }

    it 'does not have access' do
      get "/v0/vaos/appointment_requests/#{request_id}/messages"
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'loa3 user' do
    let(:current_user) { build(:user, :mhv) }

    context 'with flipper disabled' do
      it 'does not have access' do
        Flipper.disable('va_online_scheduling')
        get "/v0/vaos/appointment_requests/#{request_id}/messages"
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    it 'has access and returns messages' do
      VCR.use_cassette('vaos/messages/get_messages', match_requests_on: %i[host path method]) do
        get "/v0/vaos/appointment_requests/#{request_id}/messages"

        expect(response).to have_http_status(:success)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('vaos/messages')
      end
    end
  end
end
