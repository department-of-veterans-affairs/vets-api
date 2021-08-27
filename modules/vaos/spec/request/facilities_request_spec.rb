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

  describe '/vaos/v0/facilities' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/vaos/v0/facilities'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :mhv) }

      context 'with a single valid facility code' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_facilities', match_requests_on: %i[method uri]) do
            get '/vaos/v0/facilities', params: { facility_codes: 688 }

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/facilities')
          end
        end

        it 'returns a 200 with the correct camel-inflected schema' do
          VCR.use_cassette('vaos/systems/get_facilities', match_requests_on: %i[method uri]) do
            get '/vaos/v0/facilities', params: { facility_codes: 688 }, headers: inflection_header

            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('vaos/facilities')
          end
        end
      end

      context 'with a multiple valid facility codes' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_facilities_multiple') do
            get '/vaos/v0/facilities', params: { facility_codes: [983, 984] }

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/facilities')
          end
        end

        it 'returns a 200 with the correct camel-inflected schema' do
          VCR.use_cassette('vaos/systems/get_facilities_multiple') do
            get '/vaos/v0/facilities', params: { facility_codes: [983, 984] }, headers: inflection_header

            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('vaos/facilities')
          end
        end
      end

      context 'when the facility code param is missing' do
        let(:json) { JSON.parse(response.body) }

        it 'returns a 400 with missing param info' do
          VCR.use_cassette('vaos/systems/get_facilities', match_requests_on: %i[method uri]) do
            get '/vaos/v0/facilities'

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq('The required parameter "facility_codes", is missing')
          end
        end
      end
    end
  end

  describe '/vaos/v0/facility/:id/clinics' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/vaos/v0/facilities/984/clinics', params: { type_of_care_id: '323', system_id: '984GA' }
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :mhv) }

      context 'with a valid GET response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            allow(Rails.logger).to receive(:info).at_least(:once)
            get '/vaos/v0/facilities/983/clinics', params: { type_of_care_id: '323', system_id: '983' }

            expect(Rails.logger).to have_received(:info).with('Clinic names returned',
                                                              ['Green Team Clinic1', 'CHY PC CASSIDY',
                                                               'Green Team Clinic2', 'CHY PC VAR2']).at_least(:once)
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/facility_clinics')
          end
        end

        it 'returns a 200 with the correct camel-inflected schema' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get '/vaos/v0/facilities/983/clinics',
                params: { type_of_care_id: '323', system_id: '983' },
                headers: inflection_header

            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('vaos/facility_clinics')
          end
        end
      end

      context 'when a param is missing' do
        let(:json) { JSON.parse(response.body) }

        it 'returns a 400 with missing param type_of_care_id' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get '/vaos/v0/facilities/984/clinics', params: { system_id: '984GA' }

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq('The required parameter "type_of_care_id", is missing')
          end
        end

        it 'returns a 400 with missing param system_id' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get '/vaos/v0/facilities/984/clinics', params: { type_of_care_id: '323' }

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq('The required parameter "system_id", is missing')
          end
        end
      end
    end
  end

  describe '/vaos/v0/facilities/:id/cancel_reasons' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/vaos/v0/facilities/984/cancel_reasons'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :mhv) }

      context 'with a valid GET response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_cancel_reasons', match_requests_on: %i[method uri]) do
            get '/vaos/v0/facilities/984/cancel_reasons'

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/facility_cancel_reasons')
          end
        end

        it 'returns a 200 with the correct camel-inflected schema' do
          VCR.use_cassette('vaos/systems/get_cancel_reasons', match_requests_on: %i[method uri]) do
            get '/vaos/v0/facilities/984/cancel_reasons', headers: inflection_header

            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('vaos/facility_cancel_reasons')
          end
        end
      end
    end
  end

  describe '/vaos/v0/facilities/:id/available_appointments' do
    let(:facility_id) { '688' }
    let(:start_date) { DateTime.new(2019, 11, 22).to_s }
    let(:end_date) { DateTime.new(2020, 2, 19).to_s }
    let(:clinic_ids) { ['2276'] }
    let(:params) do
    end

    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get "/vaos/v0/facilities/#{facility_id}/cancel_reasons", params: {
          start_date: start_date,
          end_date: end_date,
          clinic_ids: clinic_ids
        }
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :mhv) }
      let(:json) { JSON.parse(response.body) }

      context 'with a valid GET response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_facility_available_appointments', match_requests_on: %i[method uri]) do
            get "/vaos/v0/facilities/#{facility_id}/available_appointments", params: {
              start_date: start_date,
              end_date: end_date,
              clinic_ids: clinic_ids
            }

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/facility_available_appointments')
          end
        end

        it 'returns a 200 with the correct camel-inflected schema' do
          VCR.use_cassette('vaos/systems/get_facility_available_appointments', match_requests_on: %i[method uri]) do
            get "/vaos/v0/facilities/#{facility_id}/available_appointments",
                params: {
                  start_date: start_date,
                  end_date: end_date,
                  clinic_ids: clinic_ids
                },
                headers: inflection_header

            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('vaos/facility_available_appointments')
          end
        end
      end

      context 'when start_date is missing' do
        it 'returns a 400 with missing param start_date' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get "/vaos/v0/facilities/#{facility_id}/available_appointments", params: {
              end_date: end_date,
              clinic_ids: clinic_ids
            }

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq('The required parameter "start_date", is missing')
          end
        end
      end

      context 'when end_date is missing' do
        it 'returns a 400 with missing param end_date' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get "/vaos/v0/facilities/#{facility_id}/available_appointments", params: {
              start_date: start_date,
              clinic_ids: clinic_ids
            }

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq('The required parameter "end_date", is missing')
          end
        end
      end

      context 'when clinic_ids is missing' do
        it 'returns a 400 with missing param clinic_ids' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get "/vaos/v0/facilities/#{facility_id}/available_appointments", params: {
              start_date: start_date,
              end_date: end_date
            }

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq('The required parameter "clinic_ids", is missing')
          end
        end
      end

      context 'when start_date is an invalid date' do
        let(:start_date) { '2019-22-11T00:00:00+00:00' }

        it 'returns a 400 with invalid date format' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get "/vaos/v0/facilities/#{facility_id}/available_appointments", params: {
              start_date: start_date,
              end_date: end_date,
              clinic_ids: clinic_ids
            }

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq(
              '"2019-22-11T00:00:00+00:00" is not a valid value for "start_date"'
            )
          end
        end
      end

      context 'when end_date is an invalid date' do
        let(:end_date) { '2019-35-11T00:00:00+00:00' }

        it 'returns a 400 with invalid date format' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get "/vaos/v0/facilities/#{facility_id}/available_appointments", params: {
              start_date: start_date,
              end_date: end_date,
              clinic_ids: clinic_ids
            }

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq(
              '"2019-35-11T00:00:00+00:00" is not a valid value for "end_date"'
            )
          end
        end
      end
    end
  end

  describe 'GET /vaos/v0/facilities/:facility_id/limits' do
    let(:user) { build(:user, :mhv) }

    context 'with a valid GET facility limits response' do
      it 'returns a 200 with the correct schema' do
        VCR.use_cassette('vaos/systems/get_facility_limits', match_requests_on: %i[method uri]) do
          get '/vaos/v0/facilities/688/limits', params: { type_of_care_id: '323' }

          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('vaos/facility_limits')
        end
      end

      it 'returns a 200 with the correct camel-inflected schema' do
        VCR.use_cassette('vaos/systems/get_facility_limits', match_requests_on: %i[method uri]) do
          get '/vaos/v0/facilities/688/limits', params: { type_of_care_id: '323' }, headers: inflection_header

          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('vaos/facility_limits')
        end
      end
    end

    context 'when type_of_care_id is missing' do
      it 'returns an error message with the missing param' do
        VCR.use_cassette('vaos/systems/get_facility_limits', match_requests_on: %i[method uri]) do
          get '/vaos/v0/facilities/688/limits'

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "type_of_care_id", is missing')
        end
      end
    end
  end

  describe 'GET /vaos/v0/facilities/limits', :skip_mvi do
    let(:user) { build(:user, :vaos) }

    context 'with a valid GET facility limits response' do
      it 'returns a 200 with the correct schema' do
        VCR.use_cassette('vaos/systems/get_facilities_limits_for_multiple', match_requests_on: %i[method path]) do
          get '/vaos/v0/facilities/limits', params: { type_of_care_id: '323', facility_ids: %w[688 442] }

          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)['data']
          attributes = data.first['attributes']
          expect(data.size).to eq(2)
          expect(data.first['id']).to eq('688')
          expect(attributes['number_of_requests']).to eq(0)
          expect(attributes['request_limit']).to eq(1)
          expect(response).to match_response_schema('vaos/facilities_limits')
        end
      end
    end

    context 'when type_of_care_id parameter is missing' do
      it 'returns an error message with the missing param, type_of_care_id' do
        VCR.use_cassette('vaos/systems/get_facilities_limits_for_multiple', match_requests_on: %i[method path]) do
          get '/vaos/v0/facilities/limits', params: { facility_ids: %w[688 442] }

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "type_of_care_id", is missing')
        end
      end
    end

    context 'when facility_ids parameter is missing' do
      it 'returns an error message with the missing param, facility_ids' do
        VCR.use_cassette('vaos/systems/get_facilities_limits_for_multiple', match_requests_on: %i[method path]) do
          get '/vaos/v0/facilities/limits', params: { type_of_care_id: '323' }

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "facility_ids", is missing')
        end
      end
    end

    context 'when no parameters are present' do
      it 'returns an error message with the missing param, facility_ids' do
        VCR.use_cassette('vaos/systems/get_facilities_limits_for_multiple', match_requests_on: %i[method path]) do
          get '/vaos/v0/facilities/limits', params: {}

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "facility_ids", is missing')
        end
      end
    end
  end

  describe 'GET /vaos/v0/facilities/:facility_id/visits/:schedule_type' do
    let(:user) { build(:user, :mhv) }

    context 'with a valid GET facility visits response' do
      it 'returns a 200 with the correct schema' do
        VCR.use_cassette('vaos/systems/get_facility_visits', match_requests_on: %i[method uri]) do
          get '/vaos/v0/facilities/688/visits/direct', params: { system_id: '688', type_of_care_id: '323' }

          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('vaos/facility_visits')
        end
      end

      it 'returns a 200 with the correct camel-inflected schema' do
        VCR.use_cassette('vaos/systems/get_facility_visits', match_requests_on: %i[method uri]) do
          get '/vaos/v0/facilities/688/visits/direct',
              params: { system_id: '688', type_of_care_id: '323' },
              headers: inflection_header

          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('vaos/facility_visits')
        end
      end
    end

    context 'when schedule_type is invalid' do
      it 'returns an error message with the invalid param' do
        VCR.use_cassette('vaos/systems/get_facility_visits', match_requests_on: %i[method uri]) do
          get '/vaos/v0/facilities/688/visits/foo', params: { system_id: '688', type_of_care_id: '323' }

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('"foo" is not a valid value for "schedule_type"')
        end
      end
    end

    context 'when system_id is missing' do
      it 'returns an error message with the missing param' do
        VCR.use_cassette('vaos/systems/get_facility_visits', match_requests_on: %i[method uri]) do
          get '/vaos/v0/facilities/688/visits/foo', params: { type_of_care_id: '323' }

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "system_id", is missing')
        end
      end
    end

    context 'when type_of_care_id is missing' do
      it 'returns an error message with the missing param' do
        VCR.use_cassette('vaos/systems/get_facility_visits', match_requests_on: %i[method uri]) do
          get '/vaos/v0/facilities/688/visits/foo', params: { system_id: '688' }

          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "type_of_care_id", is missing')
        end
      end
    end
  end
end
