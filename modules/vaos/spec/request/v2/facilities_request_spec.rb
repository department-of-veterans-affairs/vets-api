# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'facilities', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'with a loa3 user' do
    let(:user) { build(:user, :mhv) }

    describe 'GET facility clinics' do
      let(:location_id) { 442 }
      let(:patient_icn) { 321 }
      let(:clinic_ids) { %w[111 222 333] }
      let(:clinical_service) { 'primaryCare' }
      let(:page_size) { 0 }
      let(:page_number) { 0 }
      let(:params) do
        {
          location_id: location_id,
          patient_icn: patient_icn,
          clinic_ids: clinic_ids,
          clinical_service: clinical_service,
          page_size: page_size,
          page_number: page_number
        }
      end

      # TODO: record cassette from VAOS service
      it 'returns list of clinics' do
        VCR.use_cassette('vaos/v2/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
          get "/vaos/v2/locations/#{params[:location_id]}/clinics", params: params

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('vaos/v2/clinics', { strict: false })
        end
      end
    end
  end
end
