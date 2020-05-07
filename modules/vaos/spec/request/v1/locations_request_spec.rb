# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V1::Locations', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '/vaos/v1/locations' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/vaos/v1/locations'
        expect(response).to have_http_status(:forbidden)
        error_object = JSON.parse(response.body)
        expect(error_object['resourceType']).to eq('Location')
        expect(error_object['issue'].first['details']['text'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :vaos) }

      context 'with a single valid facility code' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/fhir/location/search_with_name', record: :new_episodes) do
            get '/vaos/v1/locations', params: { name: 'vamc' }
            expect(response).to have_http_status(:internal_server_error)
          end
        end
      end
    end
  end
end
