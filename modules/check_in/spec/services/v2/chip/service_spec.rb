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
          .refresh_appointments.body).to eq({ permissions: 'read.none', status: 'success', uuid: uuid }.to_json)
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
        expect(subject.build(check_in: valid_check_in, params: params)
                      .pre_check_in).to eq(hsh)
      end
    end

    context 'when token is not present' do
      let(:hsh) { { data: { error: true, message: 'Unauthorized' }, status: 401 } }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:token).and_return(nil)
      end

      it 'returns unauthorized message' do
        expect(subject.build(check_in: valid_check_in, params: params)
                      .pre_check_in).to eq(hsh)
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
end
