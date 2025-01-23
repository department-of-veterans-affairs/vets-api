# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Appointments::CheckIn', type: :request do
  include CommitteeHelper

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
      assert_schema_conform(200)
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
      assert_schema_conform(400)
      expect(response.parsed_body.dig('errors', 0, 'title')).to match('Missing parameter')
    end

    it 'shows error when nil locationId' do
      VCR.use_cassette('chip/authenticated_check_in/post_check_in_invalid_appointment_200') do
        VCR.use_cassette('chip/token/token_200') do
          post '/mobile/v0/appointments/check-in', headers: sis_headers,
                                                   params: { 'appointmentIEN' => '516', 'locationId' => nil }
        end
      end
      assert_schema_conform(400)
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
        assert_schema_conform(400)
        expect(JSON.parse(response.body).dig('errors', 0)).to eq(response_values)
      end
    end

    context 'unknown server exception' do
      let(:expected_body) do
        { 'errors' => [
          {
            'title' => 'Internal Server Error',
            'detail' => [{ 'errors' => [{ 'status' => '500', 'title' => 'Authenticated Check-in vista error' }] }],
            'code' => 'CHIP_500',
            'status' => '500'
          }
        ] }
      end

      it 'returns 500 with error message' do
        VCR.use_cassette('chip/authenticated_check_in/post_check_in_unknown_server_error_500') do
          VCR.use_cassette('chip/token/token_200') do
            params = { appointmentIEN: 'test-appt-ien', patient_dfn: 'test-patient-dfn', station_no: 'test-station-no' }
            post '/mobile/v0/appointments/check-in', headers: sis_headers, params:
          end
        end
        assert_schema_conform(500)
        expect(response.parsed_body).to eq(expected_body)
      end
    end

    context 'when token call returns a failure' do
      let(:expected_body) do
        { 'errors' => [
          {
            'title' => 'Internal Server Error',
            'detail' => [
              {
                'status' => '500',
                'title' => 'Could not retrieve a token from LoROTA'
              }
            ],
            'code' => 'CHIP_500',
            'status' => '500'
          }
        ] }
      end

      it 'throws exception' do
        VCR.use_cassette('chip/token/token_500') do
          params = { appointmentIEN: 'test-appt-ien', patient_dfn: 'test-patient-dfn', station_no: 'test-station-no' }
          post '/mobile/v0/appointments/check-in', headers: sis_headers, params:
        end

        assert_schema_conform(500)
        expect(response.parsed_body).to eq(expected_body)
      end
    end
  end
end
