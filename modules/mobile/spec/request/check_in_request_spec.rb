# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'

RSpec.describe 'check in', type: :request do
  let(:attributes) { response.parsed_body.dig('data', 'attributes') }
  let!(:user) { sis_user }

  describe 'POST /mobile/v0/appointments/check-in' do
    it 'correctly updates check in when 200' do
      VCR.use_cassette('chip/authenticated_check_in/post_check_in_200') do
        VCR.use_cassette('chip/token/token_200') do
          post '/mobile/v0/appointments/check-in', headers: sis_headers,
                                                   params: { 'appointmentIEN' => '516', 'locationId' => '516' }
        end
      end

      expect(response).to have_http_status(:ok)
      expect(attributes['code']).to match('check-in-success')
      expect(attributes['message']).to match('Check-In successful')
    end

    it 'shows error when nil appointmentIEN' do
      VCR.use_cassette('chip/authenticated_check_in/post_check_in_invalid_appointment_200') do
        VCR.use_cassette('chip/token/token_200') do
          post '/mobile/v0/appointments/check-in', headers: sis_headers,
                                                   params: { 'appointmentIEN' => nil, 'locationId' => '516' }
        end
      end

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig('errors', 0, 'title')).to match('Missing parameter')
    end

    it 'shows error when nil locationId' do
      VCR.use_cassette('chip/authenticated_check_in/post_check_in_invalid_appointment_200') do
        VCR.use_cassette('chip/token/token_200') do
          post '/mobile/v0/appointments/check-in', headers: sis_headers,
                                                   params: { 'appointmentIEN' => '516', 'locationId' => nil }
        end
      end

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig('errors', 0, 'title')).to match('Missing parameter')
    end

    context 'invalid request exception' do
      let(:key) { 'CHIP_400' }
      let(:original_body) do
        { 'id' => '33611',
          'errors' =>
           [{ 'status' => '400', 'title' => 'patient-contact-info-needs-update' },
            { 'status' => '400', 'title' => 'patient-emergency-contact-needs-update' },
            { 'status' => '400', 'title' => 'patient-next-of-kin-needs-update' },
            { 'status' => '400', 'title' => 'patient-insurance-needs-update' },
            { 'status' => '400', 'title' => 'appointment-check-in-too-late' }],
          'message' => 'Check-in unsuccessful with appointmentIen: 38846, patientDfn: 366, stationNo: 530',
          'type' => 'AuthenticatedCheckinResponse' }
      end
      let(:response_values) do
        { 'title' => 'Unsuccessful Operation', 'status' => '400', 'detail' => [original_body],
          'code' => key }
      end

      it 'returns 400 with error message' do
        VCR.use_cassette('chip/authenticated_check_in/post_check_in_invalid_argument_error_400') do
          VCR.use_cassette('chip/token/token_200') do
            params = { appointmentIEN: 'test-appt-ien', patient_dfn: 'test-patient-dfn', station_no: 'test-station-no' }
            post '/mobile/v0/appointments/check-in', headers: sis_headers, params:
          end
        end
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body).dig('errors', 0)).to eq(response_values)
      end
    end
  end
end
