# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V1::Location', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '/vaos/v1/Location' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/vaos/v1/Location'
        expect(response).to have_http_status(:forbidden)
        error_object = JSON.parse(response.body)
        expect(error_object['resourceType']).to eq('Location')
        expect(error_object['issue'].first['details']['text'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :vaos) }

      context 'with a location id' do
        it 'returns a 200 returning Location resource corresponding to that id' do
          VCR.use_cassette('vaos/fhir/location/read_by_id', record: :new_episodes) do
            get '/vaos/v1/Location/393833'
            expect(response).to have_http_status(:success)
          end
        end
      end
    end
  end
end
