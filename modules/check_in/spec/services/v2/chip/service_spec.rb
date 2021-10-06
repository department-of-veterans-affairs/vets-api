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
    let(:opts) do
      {
        path: '/dev/actions/check-in/d602d9eb-9a31-484f-9637-13ab0b507e0d',
        access_token: 'abc123',
        params: { appointmentIEN: '123-456-abc' }
      }
    end
    let(:resp) { 'Checkin successful' }
    let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }

    it 'returns a Faraday::Response' do
      allow_any_instance_of(V2::Chip::Session).to receive(:retrieve).and_return('abc123')
      allow_any_instance_of(V2::Chip::Request).to receive(:post).with(opts).and_return(faraday_response)

      hsh = { data: faraday_response.body, status: faraday_response.status }

      Rails.cache.write(
        'check_in_lorota_v2_d602d9eb-9a31-484f-9637-13ab0b507e0d_read.full',
        '12345',
        namespace: 'check-in-lorota-v2-cache'
      )

      expect(subject.build(check_in: valid_check_in, params: { appointment_ien: '123-456-abc' })
        .create_check_in).to eq(hsh)
    end
  end

  describe '#refresh_appointments' do
    let(:opts) do
      {
        path: '/dev/actions/refresh-appointments/d602d9eb-9a31-484f-9637-13ab0b507e0d',
        access_token: 'abc123',
        params: { patientDFN: '123', stationNo: '888' }
      }
    end
    let(:appointment_identifiers) do
      {
        data: {
          id: 'e602d9eb-8a31-384f-1637-33ab0b507e0d',
          type: :appointment_identifier,
          attributes: { patientDFN: '123', stationNo: '888' }
        }
      }
    end
    let(:resp) { 'Refresh successful' }
    let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }

    it 'returns a Faraday::Response' do
      allow_any_instance_of(V2::Chip::Session).to receive(:retrieve).and_return('abc123')
      allow_any_instance_of(V2::Chip::Request).to receive(:post).with(opts).and_return(faraday_response)

      Rails.cache.write(
        'check_in_lorota_v2_d602d9eb-9a31-484f-9637-13ab0b507e0d_read.full',
        '12345',
        namespace: 'check-in-lorota-v2-cache'
      )

      Rails.cache.write(
        'check_in_lorota_v2_appointment_identifiers_d602d9eb-9a31-484f-9637-13ab0b507e0d',
        appointment_identifiers.to_json,
        namespace: 'check-in-lorota-v2-cache'
      )

      expect(subject.build(check_in: valid_check_in, params: { appointment_ien: '123-456-abc' })
        .refresh_appointments.body).to eq(resp)
    end
  end

  describe '#base_path' do
    it 'returns base_path' do
      expect(subject.build(check_in: valid_check_in, params: {}).base_path).to eq('dev')
    end
  end
end
