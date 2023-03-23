# frozen_string_literal: true

require 'rails_helper'

describe V2::Chip::Service do
  subject { described_class }

  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:valid_check_in) { CheckIn::V2::Session.build(data: { uuid: id, last4: '1234', last_name: 'Johnson' }, jwt: nil) }
  let(:invalid_check_in) { CheckIn::V2::Session.build(data: { uuid: '1234' }, jwt: nil) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(check_in: valid_check_in, params: {})).to be_an_instance_of(V2::Chip::Service)
    end
  end

  describe '#create_check_in' do
    let(:resp) { 'Checkin successful' }
    let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }
    let(:hsh) { { data: faraday_response.body, status: faraday_response.status } }

    context 'when token is already present' do
      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return('jwt-token-123-abc')
        allow_any_instance_of(::V2::Chip::Client).to receive(:check_in_appointment)
          .and_return(Faraday::Response.new(body: 'Checkin successful', status: 200))
      end

      it 'returns correct response' do
        expect(subject.build(check_in: valid_check_in, params: { appointment_ien: '123-456-abc' })
          .create_check_in).to eq(hsh)
      end
    end

    context 'when token is not present' do
      let(:hsh) { { data: { error: true, message: 'Unauthorized' }, status: 401 } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return(nil)
      end

      it 'returns unauthorized' do
        expect(subject.build(check_in: valid_check_in, params: { appointment_ien: '123-456-abc' })
          .create_check_in).to eq(hsh)
      end
    end
  end

  describe '#refresh_appointments' do
    let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
    let(:appointment_identifiers) do
      {
        data: {
          id: uuid,
          type: :appointment_identifier,
          attributes: { patientDFN: '123', stationNo: '888' }
        }
      }
    end
    let(:resp) { 'Refresh successful' }

    context 'when token is already present' do
      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return('jwt-token-123-abc')
        allow_any_instance_of(::V2::Chip::Client).to receive(:refresh_appointments)
          .and_return(Faraday::Response.new(body: 'Refresh successful', status: 200))
        Rails.cache.write(
          "check_in_lorota_v2_appointment_identifiers_#{uuid}",
          appointment_identifiers.to_json,
          namespace: 'check-in-lorota-v2-cache'
        )
      end

      it 'returns correct response' do
        expect(subject.build(check_in: valid_check_in, params: { appointment_ien: '123-456-abc' })
          .refresh_appointments.body).to eq(resp)
      end
    end

    context 'when token is not present' do
      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return(nil)
      end

      it 'returns unauthorized' do
        expect(subject.build(check_in: valid_check_in, params: { appointment_ien: '123-456-abc' })
          .refresh_appointments.body).to eq({ permissions: 'read.none', status: 'success', uuid: }.to_json)
      end
    end
  end

  describe '#pre_check_in' do
    let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
    let(:params) do
      {
        demographics_up_to_date: true,
        next_of_kin_up_to_date: true,
        check_in_type: :pre_check_in
      }
    end

    context 'when token is already present' do
      let(:resp) { 'Pre-checkin successful' }
      let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }
      let(:hsh) { { data: faraday_response.body, status: faraday_response.status } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return('jwt-token-123-abc')
        allow_any_instance_of(::V2::Chip::Client).to receive(:pre_check_in)
          .and_return(faraday_response)
      end

      it 'returns correct response' do
        expect(subject.build(check_in: valid_check_in, params:)
                      .pre_check_in).to eq(hsh)
      end
    end

    context 'when token is not present' do
      let(:hsh) { { data: { error: true, message: 'Unauthorized' }, status: 401 } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return(nil)
      end

      it 'returns unauthorized message' do
        expect(subject.build(check_in: valid_check_in, params:)
                      .pre_check_in).to eq(hsh)
      end
    end
  end

  describe '#set_precheckin_started' do
    context 'when token is present and CHIP returns success response' do
      let(:resp) { Faraday::Response.new(body: { 'uuid' => id }.to_json, status: 200) }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return('jwt-token-123-abc')
        allow_any_instance_of(::V2::Chip::Client).to receive(:set_precheckin_started)
          .and_return(resp)
      end

      it 'returns success response' do
        response = subject.build(check_in: valid_check_in).set_precheckin_started
        expect(response.body).to eq(resp.body)
        expect(response.status).to eq(200)
      end
    end

    context 'when token is present but CHIP returns error' do
      let(:resp) { Faraday::Response.new(body: { 'title' => 'An error was encountered.' }.to_json, status: 500) }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return('jwt-token-123-abc')
        allow_any_instance_of(::V2::Chip::Client).to receive(:set_precheckin_started)
          .and_return(resp)
      end

      it 'returns the original response' do
        response = subject.build(check_in: valid_check_in).set_precheckin_started
        expect(response.body).to eq(resp.body)
        expect(response.status).to eq(resp.status)
      end
    end

    context 'when token is not present' do
      let(:resp) { { permissions: 'read.none', status: 'success', uuid: id } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return(nil)
      end

      it 'returns unauthorized message' do
        response = subject.build(check_in: valid_check_in).set_precheckin_started
        expect(response.body).to eq(resp.to_json)
        expect(response.status).to eq(401)
      end
    end
  end

  describe '#token' do
    context 'when it exists in redis' do
      before do
        allow_any_instance_of(::V2::Chip::RedisClient).to receive(:get).and_return('jwt-token-123-abc')
      end

      it 'returns token from redis' do
        expect(subject.build.token).to eq('jwt-token-123-abc')
      end
    end

    context 'when it does not exist in redis' do
      before do
        allow_any_instance_of(::V2::Chip::Client).to receive(:token)
          .and_return(Faraday::Response.new(body: { token: 'jwt-token-123-abc' }.to_json, status: 200))
      end

      it 'returns token from redis' do
        expect(subject.build.token).to eq('jwt-token-123-abc')
      end
    end
  end

  describe '#confirm_demographics' do
    let(:params) do
      {
        demographicConfirmations: {
          demographicsNeedsUpdate: false,
          demographicsConfirmedAt: '2021-11-30T20:45:03.779Z',
          nextOfKinNeedsUpdate: false,
          nextOfKinConfirmedAt: '2021-11-30T20:45:03.779Z',
          emergencyContactNeedsUpdate: true,
          emergencyContactConfirmedAt: '2021-11-30T20:45:03.779Z'
        },
        patientDfn: '888',
        stationNo: '500'
      }
    end

    context 'when token is already present' do
      let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
      let(:appointment_identifiers) do
        {
          data: {
            id: uuid,
            type: :appointment_identifier,
            attributes: { patientDFN: '123', stationNo: '888' }
          }
        }
      end

      let(:resp) do
        {
          data: {
            attributes: {
              id: 5,
              patientDfn: '888',
              demographicsNeedsUpdate: false,
              demographicsConfirmedAt: '2021-11-30T20:45:03.779Z',
              nextOfKinNeedsUpdate: false,
              nextOfKinConfirmedAt: '2021-11-30T20:45:03.779Z',
              emergencyContactNeedsUpdate: true,
              emergencyContactConfirmedAt: '2021-11-30T20:45:03.779Z',
              insuranceVerificationNeeded: nil
            }
          },
          id: '888'
        }
      end

      let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }
      let(:hsh) { { data: faraday_response.body, status: faraday_response.status } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return('jwt-token-123-abc')
        allow_any_instance_of(::V2::Chip::Client).to receive(:confirm_demographics).and_return(faraday_response)
        Rails.cache.write(
          "check_in_lorota_v2_appointment_identifiers_#{uuid}",
          appointment_identifiers.to_json,
          namespace: 'check-in-lorota-v2-cache'
        )
      end

      it 'returns demographics confirmation response' do
        expect(subject.build(check_in: valid_check_in, params:)
                    .confirm_demographics).to eq(hsh)
      end
    end

    context 'when token is not present' do
      let(:error_response) { { data: { error: true, message: 'Unauthorized' }, status: 401 } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return(nil)
      end

      it 'returns unauthorized message' do
        expect(subject.build(check_in: valid_check_in, params:)
                      .confirm_demographics).to eq(error_response)
      end
    end
  end

  describe '#refresh_precheckin' do
    context 'when token is already present' do
      let(:lorota_uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
      let(:params) do
        {
          id: lorota_uuid,
          check_in_type: :pre_check_in
        }
      end
      let(:resp) do
        {
          uuid: lorota_uuid
        }
      end
      let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }
      let(:hsh) { { data: faraday_response.body, status: faraday_response.status } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return('jwt-token-123-abc')
        allow_any_instance_of(::V2::Chip::Client).to receive(:refresh_precheckin).and_return(faraday_response)
      end

      it 'returns refresh precheckin response' do
        expect(subject.build(check_in: valid_check_in, params:)
                      .refresh_precheckin).to eq(hsh)
      end
    end

    context 'when token is not present' do
      let(:error_response) { { data: { error: true, message: 'Unauthorized' }, status: 401 } }
      let(:lorota_uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
      let(:params) do
        {
          id: lorota_uuid,
          check_in_type: :pre_check_in
        }
      end

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return(nil)
      end

      it 'returns unauthorized message' do
        expect(subject.build(check_in: valid_check_in, params:)
                      .refresh_precheckin).to eq(error_response)
      end
    end
  end

  describe '#initiate_check_in' do
    context 'when token is already present' do
      let(:lorota_uuid) { 'ce70fc80-0590-441a-8f7f-f0117f769425' }
      let(:params) do
        {
          id: lorota_uuid
        }
      end
      let(:resp) do
        {
          data: {
            attributes: {
              uuid: :lorota_uuid
            },
            id: :lorota_uuid
          },
          uuid: :lorota_uuid
        }
      end

      let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }
      let(:hsh) { { data: faraday_response.body, status: faraday_response.status } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return('jwt-token-123-abc')
        allow_any_instance_of(::V2::Chip::Client).to receive(:initiate_check_in).and_return(faraday_response)
      end

      it 'returns initiate_check_in response' do
        expect(subject.build(check_in: valid_check_in, params:)
                      .initiate_check_in).to eq(hsh)
      end
    end

    context 'when token is not present' do
      let(:error_response) { { data: { error: true, message: 'Unauthorized' }, status: 401 } }
      let(:lorota_uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
      let(:params) do
        {
          id: lorota_uuid
        }
      end

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return(nil)
      end

      it 'returns unauthorized message' do
        expect(subject.build(check_in: valid_check_in, params:)
                      .initiate_check_in).to eq(error_response)
      end
    end
  end

  describe '#delete' do
    context 'when token is already present' do
      let(:lorota_uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
      let(:params) do
        {
          id: lorota_uuid
        }
      end
      let(:resp) { 'Delete Successful' }
      let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }
      let(:hsh) { { data: faraday_response.body, status: faraday_response.status } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return('jwt-token-123-abc')
        allow_any_instance_of(::V2::Chip::Client).to receive(:delete).and_return(faraday_response)
      end

      it 'returns delete response' do
        expect(subject.build(check_in: valid_check_in, params:)
                      .delete).to eq(hsh)
      end
    end

    context 'when token is not present' do
      let(:error_response) { { data: { error: true, message: 'Unauthorized' }, status: 401 } }
      let(:lorota_uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
      let(:params) do
        {
          id: lorota_uuid
        }
      end

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return(nil)
      end

      it 'returns unauthorized message' do
        expect(subject.build(check_in: valid_check_in, params:)
                      .delete).to eq(error_response)
      end
    end
  end

  describe 'demographic_confirmations' do
    Timecop.freeze(Time.zone.now) do
      context 'when all demographics data available in check_in_body' do
        let(:params) do
          {
            demographics_up_to_date: true,
            next_of_kin_up_to_date: true,
            emergency_contact_up_to_date: false
          }
        end

        let(:demographics_confirmation_hash) do
          {
            demographicConfirmations: {
              demographicsNeedsUpdate: false,
              demographicsConfirmedAt: Time.zone.now.iso8601,
              nextOfKinNeedsUpdate: false,
              nextOfKinConfirmedAt: Time.zone.now.iso8601,
              emergencyContactNeedsUpdate: true,
              emergencyContactConfirmedAt: Time.zone.now.iso8601
            }
          }
        end

        it 'returns demographics confirmation hash with all demographics data' do
          expect(subject.build(check_in: valid_check_in, params:)
                        .demographic_confirmations).to eq(demographics_confirmation_hash)
        end
      end

      context 'when only demographics_up_to_date in check_in_body' do
        let(:params) do
          {
            demographics_up_to_date: true
          }
        end

        let(:demographics_confirmation_hash) do
          {
            demographicConfirmations: {
              demographicsNeedsUpdate: false,
              demographicsConfirmedAt: Time.zone.now.iso8601
            }
          }
        end

        it 'returns demographics confirmation with only demographics_up_to_date data' do
          expect(subject.build(check_in: valid_check_in, params:)
                        .demographic_confirmations).to eq(demographics_confirmation_hash)
        end
      end

      context 'when only next_of_kin_up_to_date in check_in_body' do
        let(:params) do
          {
            next_of_kin_up_to_date: false
          }
        end

        let(:demographics_confirmation_hash) do
          {
            demographicConfirmations: {
              nextOfKinNeedsUpdate: true,
              nextOfKinConfirmedAt: Time.zone.now.iso8601
            }
          }
        end

        it 'returns demographics confirmation with only next_of_kin_up_to_date data' do
          expect(subject.build(check_in: valid_check_in, params:)
                        .demographic_confirmations).to eq(demographics_confirmation_hash)
        end
      end

      context 'when only emergency_contact_up_to_date in check_in_body' do
        let(:params) do
          {
            emergency_contact_up_to_date: true
          }
        end

        let(:demographics_confirmation_hash) do
          {
            demographicConfirmations: {
              emergencyContactNeedsUpdate: false,
              emergencyContactConfirmedAt: Time.zone.now.iso8601
            }
          }
        end

        it 'returns demographics confirmation with only emergency_contact_up_to_date data' do
          expect(subject.build(check_in: valid_check_in, params:)
                        .demographic_confirmations).to eq(demographics_confirmation_hash)
        end
      end

      context 'when no demographics data available in check_in_body' do
        let(:demographics_confirmation_hash) do
          {
            demographicConfirmations: {}
          }
        end

        it 'returns demographics confirmation hash with no demographics data' do
          expect(subject.build(check_in: valid_check_in, params: {})
                        .demographic_confirmations).to eq(demographics_confirmation_hash)
        end
      end
    end
  end

  describe '#identifier_params' do
    let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
    let(:appointment_identifiers) do
      {
        data: {
          id: uuid,
          type: :appointment_identifier,
          attributes: { patientDFN: '123', stationNo: 888 }
        }
      }
    end
    let(:hsh) do
      {
        patientDfn: '123',
        stationNo: '888'
      }
    end

    context 'when called with appointment identifiers in cache' do
      before do
        Rails.cache.write(
          "check_in_lorota_v2_appointment_identifiers_#{uuid}",
          appointment_identifiers.to_json,
          namespace: 'check-in-lorota-v2-cache'
        )
      end

      it 'returns patientDfn and stationNo as string' do
        expect(subject.build(check_in: valid_check_in, params: {})
                      .identifier_params).to eq(hsh)
      end
    end
  end
end
