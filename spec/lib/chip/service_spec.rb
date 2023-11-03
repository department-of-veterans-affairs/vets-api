# frozen_string_literal: true

require 'rails_helper'
require 'chip/service'
require 'chip/service_exception'

describe Chip::Service do
  subject { described_class }

  let(:tenant_name) { 'mobile_app' }
  let(:tenant_id) { Settings.chip[tenant_name].tenant_id }
  let(:username) { 'test_username' }
  let(:password) { 'test_password' }
  let(:options) { { tenant_id:, tenant_name:, username:, password: } }

  describe '#initialize' do
    let(:expected_error) { ArgumentError }

    context 'when username is blank' do
      let(:expected_error_message) { 'Invalid username' }

      it 'raises error' do
        expect do
          subject.new(tenant_id:, tenant_name:, username: '', password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when password is blank' do
      let(:expected_error_message) { 'Invalid password' }

      it 'raises error' do
        expect do
          subject.new(tenant_id:, tenant_name:, username:, password: '')
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when tenant_name is blank' do
      let(:expected_error_message) { 'Invalid tenant parameters' }

      it 'raises error' do
        expect do
          subject.new(tenant_id:, tenant_name: '', username:, password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when tenant_id is blank' do
      let(:expected_error_message) { 'Invalid tenant parameters' }

      it 'raises error' do
        expect do
          subject.new(tenant_id: '', tenant_name:, username:, password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when tenant_name does not exist' do
      let(:expected_error_message) { 'Tenant parameters do not exist' }

      it 'raises error' do
        expect do
          subject.new(tenant_id:, tenant_name: 'abc', username:, password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when tenant_name and tenant_id do not match' do
      let(:expected_error_message) { 'Tenant parameters do not exist' }

      it 'raises error' do
        expect do
          subject.new(tenant_id: '12345', tenant_name:, username:, password:)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when called with valid parameters' do
      it 'creates service object' do
        service_obj = subject.new(tenant_id:, tenant_name:, username:, password:)
        expect(service_obj).to be_a(Chip::Service)
        expect(service_obj.redis_client).to be_a(Chip::RedisClient)
      end
    end
  end

  describe '#update_demographics' do
    let(:service_obj) { subject.build(options) }
    let(:patient_dfn) { 'patient_dfn_value' }
    let(:station_no) { 'station_no_value' }
    let(:demographic_confirmations) { 'demographic_confirmations_value' }

    context 'when chip returns successful response' do
      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.update_demographics.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'returns response' do
        VCR.use_cassette('chip/authenticated_demographics/update_demographics_200') do
          VCR.use_cassette('chip/token/token_200') do
            response = service_obj.update_demographics(patient_dfn:, station_no:, demographic_confirmations:)
            expect(response.status).to eq 200
            expect(JSON.parse(response.body)).to be_a Hash
          end
        end
      end
    end

    context 'when called with invalid request' do
      let(:invalid_demographic_confirmations) { '{ "demographicConfirmations": "contactNeedsUpdates" }' }
      let(:key) { 'CHIP_400' }
      let(:original_body) do
        '{
          "errors": [
            {
              "status": "400",
              "title": "Invalid arguments: \"demographicConfirmations.contactNeedsUpdates\" is not allowed"
            }
          ]
        }'
      end

      let(:response_values) { { status: 400, detail: [JSON.parse(original_body)], code: key } }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.update_demographics.fail',
                                                        tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.update_demographics.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'throws 400 bad request exception' do
        VCR.use_cassette('chip/authenticated_demographics/update_demographics_400') do
          VCR.use_cassette('chip/token/token_200') do
            expect do
              service_obj.update_demographics(patient_dfn:, station_no:,
                                              demographic_confirmations: invalid_demographic_confirmations)
            end.to raise_exception(Chip::ServiceException) { |error|
              expect(error.key).to eq(key)
              expect(error.response_values).to eq(response_values)
              expect(JSON.parse(error.original_body)).to eq(JSON.parse(original_body))
              expect(error.original_status).to eq(400)
            }
          end
        end
      end
    end

    context 'when chip returns a failure' do
      let(:key) { 'CHIP_500' }
      let(:original_body) do
        '{
            "errors": [{
              "status": "500",
              "title": "Problem getting token from VistA APIs"
            }]
        }'
      end

      let(:response_values) { { status: 500, detail: [JSON.parse(original_body)], code: key } }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.update_demographics.fail',
                                                        tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.update_demographics.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'throws exception' do
        VCR.use_cassette('chip/authenticated_demographics/update_demographics_500') do
          VCR.use_cassette('chip/token/token_200') do
            expect do
              service_obj.update_demographics(patient_dfn:, station_no:, demographic_confirmations:)
            end.to raise_exception(Chip::ServiceException) { |error|
              expect(error.key).to eq(key)
              expect(error.response_values).to eq(response_values)
              expect(JSON.parse(error.original_body)).to eq(JSON.parse(original_body))
              expect(error.original_status).to eq(500)
            }
          end
        end
      end
    end

    context 'when token call returns a failure' do
      let(:key) { 'CHIP_500' }
      let(:original_body) { '{"status":"500", "title":"Could not retrieve a token from LoROTA"}' }
      let(:response_values) { { status: 500, detail: [JSON.parse(original_body)], code: key } }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.update_demographics.fail',
                                                        tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.fail', tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.update_demographics.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'throws exception' do
        VCR.use_cassette('chip/token/token_500') do
          expect do
            service_obj.update_demographics(patient_dfn:, station_no:, demographic_confirmations:)
          end.to raise_exception(Chip::ServiceException) { |error|
            expect(error.key).to eq(key)
            expect(error.response_values).to eq(response_values)
            expect(error.original_body).to eq(original_body)
            expect(error.original_status).to eq(500)
          }
        end
      end
    end
  end

  describe 'token' do
    let(:service_obj) { subject.build(options) }
    let(:redis_client) { double }
    let(:token) { '123' }

    context 'when token is already cached in redis' do
      before do
        allow(Chip::RedisClient).to receive(:build).and_return(redis_client)
        allow(redis_client).to receive(:get).and_return(token)
      end

      it 'returns token from redis' do
        expect(service_obj).not_to receive(:get_token)

        expect(service_obj.send(:token)).to eq(token)
      end
    end

    context 'when token is not cached in redis' do
      let(:token) { 'test_token' }
      let(:faraday_response) { double('Faraday::Response', body: { 'token' => token }.to_json) }

      before do
        allow(Chip::RedisClient).to receive(:build).and_return(redis_client)
        allow(redis_client).to receive(:get).and_return(nil)
      end

      it 'calls get_token and returns token' do
        expect(service_obj).to receive(:get_token).and_return(faraday_response)
        expect(redis_client).to receive(:save).with(token:)

        expect(service_obj.send(:token)).to eq(token)
      end
    end
  end

  describe '#get_token' do
    let(:service_obj) { subject.build(options) }
    let(:response_body) { { 'token' => 'chip-123-abc' } }

    context 'when chip returns successful response' do
      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'returns response' do
        VCR.use_cassette('chip/token/token_200') do
          response = service_obj.get_token

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)).to eq(response_body)
        end
      end
    end

    context 'when chip returns a failure' do
      let(:key) { 'CHIP_500' }
      let(:original_body) { '{"status":"500", "title":"Could not retrieve a token from LoROTA"}' }
      let(:response_values) { { status: 500, detail: [JSON.parse(original_body)], code: key } }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.fail', tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'throws exception' do
        VCR.use_cassette('chip/token/token_500') do
          expect { service_obj.get_token }.to raise_exception(Chip::ServiceException) { |error|
            expect(error.key).to eq(key)
            expect(error.response_values).to eq(response_values)
            expect(error.original_body).to eq(original_body)
            expect(error.original_status).to eq(500)
          }
        end
      end
    end
  end

  describe '#post_patient_check_in' do
    let(:service_obj) { subject.build(options) }
    let(:tenant_name) { 'mobile_app' }
    let(:tenant_id) { Settings.chip[tenant_name].tenant_id }
    let(:username) { 'test_username' }
    let(:password) { 'test_password' }

    context 'successful check-in' do
      let(:response_message) do
        'success with appointmentIen: test-appt-ien, patientDfn: test-patient-ien, stationNo: test-station-no'
      end
      let(:response_body) do
        {
          'data' => {
            'attributes' => {
              'message' => response_message
            },
            'type' => 'AuthenticatedCheckinResponse'
          }
        }
      end

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.post_patient_check_in.total')
      end

      it 'returns 200 with success message' do
        VCR.use_cassette('chip/authenticated_check_in/post_check_in_200') do
          VCR.use_cassette('chip/token/token_200') do
            response = service_obj.post_patient_check_in(appointment_ien: 'test-appt-ien',
                                                         patient_dfn: 'test-patient-dfn', station_no: 'test-station-no')
            expect(response.status).to be 200
            expect(JSON.parse(response.body)).to eq(response_body)
          end
        end
      end
    end

    context 'invalid appointment response' do
      let(:response_message) do
        'Check-in unsuccessful with appointmentIen: appt-ien, patientDfn: patient-ien, stationNo: station-no'
      end
      let(:invalid_appt_response) do
        {
          'data' => {
            'attributes' => {
              'errors' => ['e-check-in-not-allowed'],
              'message' => response_message
            },
            'type' => 'AuthenticatedCheckinResponse'
          }
        }
      end

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.post_patient_check_in.total')
      end

      it 'returns 200 with error message' do
        VCR.use_cassette('chip/authenticated_check_in/post_check_in_invalid_appointment_200') do
          VCR.use_cassette('chip/token/token_200') do
            response = service_obj.post_patient_check_in(appointment_ien: 'test-appt-ien',
                                                         patient_dfn: 'test-patient-dfn', station_no: 'test-station-no')
            expect(response.status).to be 200
            expect(JSON.parse(response.body)).to eq(invalid_appt_response)
          end
        end
      end
    end

    context 'unknown server exception' do
      let(:key) { 'CHIP_500' }
      let(:original_body) do
        '{
            "errors": [
              {
                "status": "500",
                "title": "Authenticated Check-in vista error"
              }
            ]
          }'
      end

      let(:response_values) { { status: 500, detail: [JSON.parse(original_body)], code: key } }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.post_patient_check_in.fail',
                                                        tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.post_patient_check_in.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'returns 500 with error message' do
        VCR.use_cassette('chip/authenticated_check_in/post_check_in_unknown_server_error_500') do
          VCR.use_cassette('chip/token/token_200') do
            expect do
              service_obj.post_patient_check_in(appointment_ien: 'test-appt-ien',
                                                patient_dfn: 'test-patient-dfn', station_no: 'test-station-no')
            end.to raise_exception(Chip::ServiceException) { |error|
              expect(error.response_values).to eq(response_values)
              expect(JSON.parse(error.original_body)).to eq(JSON.parse(original_body))
              expect(error.original_status).to eq(500)
            }
          end
        end
      end
    end

    context 'when token call returns a failure' do
      let(:key) { 'CHIP_500' }
      let(:original_body) { '{"status":"500", "title":"Could not retrieve a token from LoROTA"}' }
      let(:response_values) { { status: 500, detail: [JSON.parse(original_body)], code: key } }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.post_patient_check_in.fail',
                                                        tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.fail', tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.post_patient_check_in.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'throws exception' do
        VCR.use_cassette('chip/token/token_500') do
          expect do
            service_obj.post_patient_check_in(appointment_ien: 'test-appt-ien',
                                              patient_dfn: 'test-patient-dfn', station_no: 'test-station-no')
          end.to raise_exception(Chip::ServiceException) { |error|
            expect(error.key).to eq(key)
            expect(error.response_values).to eq(response_values)
            expect(error.original_body).to eq(original_body)
            expect(error.original_status).to eq(500)
          }
        end
      end
    end

    context 'invalid request exception' do
      let(:key) { 'CHIP_400' }
      let(:original_body) do
        '{
            "id": "33611",
            "errors": [{
              "status": "400",
              "title": "patient-contact-info-needs-update"
            }, {
              "status": "400",
              "title": "patient-emergency-contact-needs-update"
            }, {
              "status": "400",
              "title": "patient-next-of-kin-needs-update"
            }, {
              "status": "400",
              "title": "patient-insurance-needs-update"
            }, {
              "status": "400",
              "title": "appointment-check-in-too-late"
            }],
            "message": "Check-in unsuccessful with appointmentIen: 38846, patientDfn: 366, stationNo: 530",
            "type": "AuthenticatedCheckinResponse"
        }'
      end

      let(:response_values) { { status: 400, detail: [JSON.parse(original_body)], code: key } }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.post_patient_check_in.fail',
                                                        tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.post_patient_check_in.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'returns 400 with error message' do
        VCR.use_cassette('chip/authenticated_check_in/post_check_in_invalid_argument_error_400') do
          VCR.use_cassette('chip/token/token_200') do
            expect do
              service_obj.post_patient_check_in(appointment_ien: 'test-appt-ien',
                                                patient_dfn: 'test-patient-dfn', station_no: 'test-station-no')
            end.to raise_exception(Chip::ServiceException) { |error|
              expect(error.response_values).to eq(response_values)
              expect(JSON.parse(error.original_body)).to eq(JSON.parse(original_body))
              expect(error.original_status).to eq(400)
            }
          end
        end
      end
    end
  end

  describe '#get_demographics' do
    let(:service_obj) { subject.build(options) }
    let(:patient_dfn) { 'patient_dfn_value' }
    let(:station_no) { 'station_no_value' }

    context 'successful response' do
      let(:mailing_address) do
        {
          'street1' => 'Any Street',
          'street2' => '',
          'street3' => '',
          'city' => 'Any Town',
          'county' => '',
          'state' => 'WV',
          'zip' => '999980071',
          'zip4' => nil,
          'country' => 'USA'
        }
      end
      let(:residential_address) do
        {
          'street1' => '186 Columbia Turnpike',
          'street2' => '',
          'street3' => '',
          'city' => 'Florham Park',
          'county' => '',
          'state' => 'New Mexico',
          'zip' => '07932',
          'zip4' => nil,
          'country' => 'USA'
        }
      end
      let(:emergency_contact_address) do
        {
          'street1' => '690 Holcomb Bridge Rd',
          'street2' => '',
          'street3' => '',
          'city' => 'Roswell',
          'county' => '',
          'state' => 'Georgia',
          'zip' => '30076',
          'zip4' => '',
          'country' => 'USA'
        }
      end

      let(:response_body) do
        {
          'data' => {
            'insuranceVerificationNeeded' => false,
            'needsConfirmation' => true,
            'mailingAddress' => mailing_address,
            'residentialAddress' => residential_address,
            'homePhone' => '222-555-8235',
            'officePhone' => '222-555-7720',
            'cellPhone' => '315-378-9190',
            'email' => 'payibo6648@weishu8.com',
            'emergencyContact' => {
              'name' => 'Bryant Richard',
              'relationship' => 'Brother',
              'phone' => '310-399-2006',
              'workPhone' => '708-391-9015',
              'address' => emergency_contact_address,
              'needsConfirmation' => true
            },
            'nextOfKin' => {
              'needsConfirmation' => true
            }
          },
          'id' => '366',
          'type' => 'authenticatedGetDemographicsResponse'
        }
      end

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_demographics.total')
      end

      it 'returns 200 with success message' do
        VCR.use_cassette('chip/authenticated_demographics/get_demographics_200', erb: { patient_dfn:, station_no: }) do
          VCR.use_cassette('chip/token/token_200') do
            response = service_obj.get_demographics(patient_dfn:, station_no:)
            expect(response.status).to be 200
            expect(JSON.parse(response.body)).to eq(response_body)
          end
        end
      end
    end

    context 'when chip returns a failure' do
      let(:key) { 'CHIP_500' }
      let(:original_body) do
        '{
            "errors": [{
              "status": "500",
              "title": "Error getting demographics from VistA API: Request failed with status code 500"
            }]
        }'
      end

      let(:response_values) { { status: 500, detail: [JSON.parse(original_body)], code: key } }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.get_demographics.fail',
                                                        tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.get_demographics.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'throws 500 for error from Vista API' do
        VCR.use_cassette('chip/authenticated_demographics/get_demographics_500', erb: { patient_dfn:, station_no: }) do
          VCR.use_cassette('chip/token/token_200') do
            expect do
              service_obj.get_demographics(patient_dfn:, station_no:)
            end.to raise_exception(Chip::ServiceException) { |error|
              expect(error.key).to eq(key)
              expect(error.response_values).to eq(response_values)
              expect(JSON.parse(error.original_body)).to eq(JSON.parse(original_body))
              expect(error.original_status).to eq(500)
            }
          end
        end
      end
    end

    context 'when token call returns a failure' do
      let(:key) { 'CHIP_500' }
      let(:original_body) { '{"status":"500", "title":"Could not retrieve a token from LoROTA"}' }
      let(:response_values) { { status: 500, detail: [JSON.parse(original_body)], code: key } }

      before do
        expect(StatsD).to receive(:increment).once.with('api.chip.get_demographics.fail',
                                                        tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.fail', tags: ['error:ChipServiceException'])
        expect(StatsD).to receive(:increment).once.with('api.chip.get_demographics.total')
        expect(StatsD).to receive(:increment).once.with('api.chip.get_token.total')
      end

      it 'throws exception' do
        VCR.use_cassette('chip/token/token_500') do
          expect do
            service_obj.get_demographics(patient_dfn:, station_no:)
          end.to raise_exception(Chip::ServiceException) { |error|
            expect(error.key).to eq(key)
            expect(error.response_values).to eq(response_values)
            expect(error.original_body).to eq(original_body)
            expect(error.original_status).to eq(500)
          }
        end
      end
    end
  end
end
