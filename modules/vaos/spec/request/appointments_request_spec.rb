# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'vaos appointments', type: :request, skip_mvi: true do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'loa1 user' do
    let(:current_user) { build(:user, :loa1) }

    describe 'GET appointments' do
      it 'does not have access' do
        get '/vaos/v0/appointments'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    describe 'POST appointments' do
      it 'does not have access' do
        post '/vaos/v0/appointments'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    describe 'PUT appointments/cancel' do
      it 'does not have access' do
        put '/vaos/v0/appointments/cancel'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end
  end

  context 'loa3 user' do
    let(:current_user) { build(:user, :vaos) }

    describe 'GET appointments' do
      let(:start_date) { Time.zone.parse('2020-06-02T07:00:00Z') }
      let(:end_date) { Time.zone.parse('2020-07-02T08:00:00Z') }
      let(:params) { { type: 'va', start_date: start_date, end_date: end_date } }

      context 'with flipper disabled' do
        it 'does not have access' do
          Flipper.disable('va_online_scheduling')
          get '/vaos/v0/appointments'
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'without icn' do
        before { stub_mpi_not_found }

        let(:current_user) { build(:user, :mhv, mhv_icn: nil) }

        it 'does not have access' do
          get '/vaos/v0/appointments'
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('No patient ICN found')
        end
      end

      context 'without a type' do
        it 'has a parameter missing exception' do
          get '/vaos/v0/appointments', params: params.except(:type)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "type", is missing')
        end
      end

      context 'without a start_date' do
        it 'has a parameter missing exception' do
          get '/vaos/v0/appointments', params: params.except(:start_date)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "start_date", is missing')
        end
      end

      context 'without an end_date' do
        it 'has a parameter missing exception' do
          get '/vaos/v0/appointments', params: params.except(:end_date)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "end_date", is missing')
        end
      end

      context 'with an invalid type' do
        it 'has an invalid field type exception' do
          get '/vaos/v0/appointments', params: params.merge(type: 'invalid')
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('"invalid" is not a valid value for "type"')
        end
      end

      context 'with an invalid start_date' do
        it 'has an invalid field type exception' do
          get '/vaos/v0/appointments', params: params.merge(start_date: 'invalid')
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('"invalid" is not a valid value for "start_date"')
        end
      end

      context 'with an invalid end_date' do
        it 'has an invalid field type exception' do
          get '/vaos/v0/appointments', params: params.merge(end_date: 'invalid')
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('"invalid" is not a valid value for "end_date"')
        end
      end

      context 'returns list of appointments' do
        it 'has access and returns va appointments' do
          VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments', params: params

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data'].first['id']).to eq('202006031600983000030800000000000000')
            expect(response).to match_response_schema('vaos/va_appointments', { strict: false })
          end
        end

        it 'has access and returns va appointments having partial errors' do
          VCR.use_cassette('vaos/appointments/get_appointments_200_partial_error', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments', params: params

            expect(response).to have_http_status(:multi_status)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data'].first['id']).to eq('202006031600983000030800000000000000')
            expect(response).to match_response_schema('vaos/va_appointments', { strict: false })
          end
        end

        it 'increments statsD on a partial' do
          VCR.use_cassette('vaos/appointments/get_appointments_200_partial_error', match_requests_on: %i[method uri]) do
            expect { get('/vaos/v0/appointments', params: params) }
              .to trigger_statsd_increment(
                'api.vaos.va_mobile.response.partial',
                tags: ['errors:[{:code=>1 :source=>"test result" :summary=>"test summary"}]']
              )
          end
        end

        it 'has access and returns va appointments when camel-inflected' do
          VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments', params: params, headers: inflection_header

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_camelized_response_schema('vaos/va_appointments', { strict: false })
          end
        end
      end

      context 'shows single appointment' do
        it 'returns single appointment based on appointment id' do
          VCR.use_cassette('vaos/appointments/show_appointment', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments/va/202006031600983000030800000000000000.aaaaaa', params: params
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['id']).to eq('202006031600983000030800000000000000.aaaaaa')
            expect(response).to match_response_schema('vaos/va_appointment')
          end
        end

        it 'returns single appointment based on appointment id when camel-inflected' do
          VCR.use_cassette('vaos/appointments/show_appointment', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments/va/202006031600983000030800000000000000.aaaaaa',
                params: params,
                headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['id']).to eq('202006031600983000030800000000000000.aaaaaa')
            expect(response).to match_camelized_response_schema('vaos/va_appointment')
          end
        end
      end

      context 'when the upstream service returns an http status of 204, no content' do
        it 'returns an http status of 404 to the vets website' do
          VCR.use_cassette('vaos/appointments/show_appointment', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments/va/123456789101112'
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      context 'when the upstream service returns an http status of 204, no content and X-Key-Inflection set' do
        it 'returns an http status of 404 to the vets website' do
          VCR.use_cassette('vaos/appointments/show_appointment', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments/va/123456789101112', params: params, headers: inflection_header
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      context 'shows single appointment with dash in app id' do
        it 'returns single appointment based on appointment id' do
          VCR.use_cassette('vaos/appointments/show_appointment_with_dash', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments/va/202006031600983000030800000000000000-aaaaaa', params: params
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['id']).to eq('202006031600983000030800000000000000-aaaaaa')
            expect(response).to match_response_schema('vaos/va_appointment')
          end
        end

        it 'returns single appointment based on appointment id when camel-inflected' do
          VCR.use_cassette('vaos/appointments/show_appointment_with_dash', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments/va/202006031600983000030800000000000000-aaaaaa',
                params: params,
                headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['id']).to eq('202006031600983000030800000000000000-aaaaaa')
            expect(response).to match_camelized_response_schema('vaos/va_appointment')
          end
        end
      end

      context 'cc appointments' do
        it 'has access and returns cc appointments' do
          VCR.use_cassette('vaos/appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments', params: params.merge(type: 'cc')
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('vaos/cc_appointments')
          end
        end

        it 'has access and returns cc appointments when camel-inflected' do
          VCR.use_cassette('vaos/appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments', params: params.merge(type: 'cc'), headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_camelized_response_schema('vaos/cc_appointments')
          end
        end
      end

      context 'with no appointments' do
        it 'returns an empty list' do
          VCR.use_cassette('vaos/appointments/get_appointments_empty', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments', params: params
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(
              'data' => [],
              'meta' => {
                'pagination' => {
                  'current_page' => 0,
                  'per_page' => 0,
                  'total_entries' => 0,
                  'total_pages' => 0
                },
                'errors' => []
              }
            )
            expect(response).to match_response_schema('vaos/va_appointments')
          end
        end

        it 'returns an empty list when camel-inflected' do
          VCR.use_cassette('vaos/appointments/get_appointments_empty', match_requests_on: %i[method uri]) do
            get '/vaos/v0/appointments', params: params, headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq(
              'data' => [],
              'meta' => {
                'pagination' => {
                  'currentPage' => 0,
                  'perPage' => 0,
                  'totalEntries' => 0,
                  'totalPages' => 0
                },
                'errors' => []
              }
            )
            expect(response).to match_camelized_response_schema('vaos/va_appointments')
          end
        end
      end

      context 'with a response that includes blank providers' do
        it 'parses the data and does not throw an undefined method error' do
          VCR.use_cassette('vaos/appointments/get_appointments_map_error',
                           match_requests_on: %i[method uri], tag: :force_utf8) do
            get '/vaos/v0/appointments', params: params
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/va_appointments', { strict: false })
          end
        end

        it 'parses the data and does not throw an undefined method error when camel-inflected' do
          VCR.use_cassette('vaos/appointments/get_appointments_map_error',
                           match_requests_on: %i[method uri], tag: :force_utf8) do
            get '/vaos/v0/appointments', params: params, headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('vaos/va_appointments', { strict: false })
          end
        end
      end
    end

    describe 'POST appointments' do
      let(:error_detail) do
        'This appointment cannot be booked using VA Online Scheduling.  Please contact the site directly to schedule ' \
          'your appointment and advise them to <b>contact the VAOS Support Team for assistance with Clinic configurat' \
          'ion.</b> <a class="external-link" href="https://www.va.gov/find-locations/">VA Facility Locator</a>'
      end

      context 'with flipper disabled' do
        it 'does not have access' do
          Flipper.disable('va_online_scheduling')
          post '/vaos/v0/appointments'

          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'when appointment cannot be created due to conflict' do
        let(:request_body) do
          FactoryBot.build(:appointment_form, :ineligible).attributes
        end

        it 'returns bad request with detail in errors' do
          VCR.use_cassette('vaos/appointments/post_appointment_409', match_requests_on: %i[method uri]) do
            allow(Rails.logger).to receive(:warn).at_least(:once)
            post '/vaos/v0/appointments', params: request_body

            expect(response).to have_http_status(:conflict)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq(error_detail)
            expect(Rails.logger).to have_received(:warn).with('Direct schedule submission error',
                                                              any_args).at_least(:once)
          end
        end
      end

      context 'when appointment is invalid' do
        let(:request_body) do
          FactoryBot.build(:appointment_form, :ineligible).attributes
        end

        it 'returns bad request with detail in errors' do
          VCR.use_cassette('vaos/appointments/post_appointment_400', match_requests_on: %i[method uri]) do
            expect(Rails.logger).to receive(:warn).with('Direct schedule submission error', any_args)
            expect(Rails.logger).to receive(:warn).with('VAOS service call failed!', any_args)
            expect(Rails.logger).to receive(:warn).with(
              'Clinic does not support VAOS appointment create',
              clinic_id: request_body[:clinic]['clinic_id'],
              site_code: request_body[:clinic]['site_code']
            )

            post '/vaos/v0/appointments', params: request_body

            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq(error_detail)
          end
        end
      end

      context 'when appointment can be created' do
        let(:request_body) do
          FactoryBot.build(:appointment_form, :eligible).attributes
        end

        it 'creates the appointment' do
          VCR.use_cassette('vaos/appointments/post_appointment', match_requests_on: %i[method uri]) do
            post '/vaos/v0/appointments', params: request_body

            expect(response).to have_http_status(:no_content)
            expect(response.body).to be_an_instance_of(String).and be_empty
          end
        end
      end
    end

    describe 'PUT appointments/cancel' do
      context 'with flipper disabled' do
        it 'does not have access' do
          Flipper.disable('va_online_scheduling')
          put '/vaos/v0/appointments/cancel'

          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'when request body validation fails' do
        it 'returns validation failed' do
          put '/vaos/v0/appointments/cancel'

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['errors'].size).to eq(3)
        end
      end

      context 'when appointment cannot be cancelled' do
        let(:request_body) do
          {
            appointment_time: '11/15/19 20:00:00',
            clinic_id: '408',
            facility_id: '983',
            cancel_reason: 'whatever',
            cancel_code: '5',
            remarks: nil,
            clinic_name: nil
          }
        end

        it 'returns bad request with detail in errors' do
          VCR.use_cassette('vaos/appointments/put_cancel_appointment_409', match_requests_on: %i[method uri]) do
            expect(Rails.logger).to receive(:warn).with('VAOS service call failed!', any_args).once
            expect(Rails.logger).to receive(:warn).with(
              'Clinic does not support VAOS appointment cancel',
              clinic_id: request_body[:clinic_id],
              site_code: request_body[:facility_id]
            ).once
            # We're checking that the logger is called twice to account for behavior in sentry_logging.rb lines 25-30
            expect(Rails.logger).to receive(:warn).twice
            put '/vaos/v0/appointments/cancel', params: request_body

            expect(response).to have_http_status(:conflict)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq('This appointment cannot be cancelled using VA Online Scheduling.  Please contact the site direc' \
                     'tly to cancel your appointment. <a class="external-link" ' \
                     'href="https://www.va.gov/find-locations/">VA Facility Locator</a>')
          end
        end
      end

      context 'when appointment can be cancelled' do
        let(:request_body) do
          {
            appointment_time: '11/15/2019 13:00:00',
            clinic_id: '437',
            facility_id: '983',
            cancel_reason: '5',
            cancel_code: 'PC',
            remarks: '',
            clinic_name: 'CHY OPT VAR1'
          }
        end

        it 'cancels the appointment' do
          VCR.use_cassette('vaos/appointments/put_cancel_appointment', match_requests_on: %i[method uri]) do
            put '/vaos/v0/appointments/cancel', params: request_body

            expect(response).to have_http_status(:no_content)
            expect(response.body).to be_an_instance_of(String).and be_empty
          end
        end
      end
    end
  end
end
