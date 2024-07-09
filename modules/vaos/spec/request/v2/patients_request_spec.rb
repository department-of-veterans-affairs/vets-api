# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'vaos patients', :skip_mvi, type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'loa3 user' do
    let(:current_user) { build(:user, :vaos) }

    describe 'GET patient' do
      let(:params) { { clinical_service_id: 'primaryCare', facility_id: '100', type: 'direct' } }

      context 'using VAOS' do
        before do
          Flipper.disable(:va_online_scheduling_use_vpg)
          Flipper.disable(:va_online_scheduling_enable_OH_eligibility)
        end

        context 'patient appointment meta data' do
          it 'successfully returns patient appointment metadata' do
            VCR.use_cassette('vaos/v2/patients/get_patient_appointment_metadata_vaos',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/eligibility', params:, headers: inflection_header
              expect(response).to have_http_status(:ok)
              attributes = JSON.parse(response.body)['data']['attributes']
              expect(attributes['eligible']).to be(false)
              expect(response.body).to match_camelized_schema('vaos/v2/patient_appointment_metadata', { strict: false })
            end
          end
        end
      end

      context 'using VPG' do
        before do
          Flipper.enable(:va_online_scheduling_use_vpg)
          Flipper.enable(:va_online_scheduling_enable_OH_eligibility)
        end

        context 'patient appointment meta data' do
          it 'successfully returns patient appointment metadata' do
            VCR.use_cassette('vaos/v2/patients/get_patient_appointment_metadata_vpg',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/eligibility', params:, headers: inflection_header
              expect(response).to have_http_status(:ok)
              attributes = JSON.parse(response.body)['data']['attributes']
              expect(attributes['eligible']).to be(false)
              expect(response.body).to match_camelized_schema('vaos/v2/patient_appointment_metadata', { strict: false })
            end
          end
        end
      end
    end
  end
end
