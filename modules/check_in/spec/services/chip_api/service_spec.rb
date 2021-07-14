# frozen_string_literal: true

require 'rails_helper'

describe ChipApi::Service do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build).to be_an_instance_of(ChipApi::Service)
    end
  end

  describe '#get_check_in' do
    Timecop.freeze(Time.zone.now)

    let(:id) { '123abc' }
    let(:opts) do
      {
        path: '/dev/appointments/123abc',
        access_token: 'abc123'
      }
    end
    let(:resp) do
      {
        uuid: '123abc',
        appointment_time: Time.zone.now.to_s,
        facility_name: 'Acme VA',
        clinic_name: 'Green Team Clinic1',
        clinic_phone: '555-555-5555'
      }
    end
    let(:faraday_response) { Faraday::Response.new(body: resp.to_json) }

    it 'returns a Faraday::Response' do
      allow_any_instance_of(ChipApi::Session).to receive(:retrieve).and_return('abc123')
      allow_any_instance_of(ChipApi::Request).to receive(:get).with(opts).and_return(faraday_response)

      expect(subject.build.get_check_in(id)).to eq({ data: Oj.load(faraday_response.body) })
    end

    Timecop.return
  end

  describe '#create_check_in' do
    let(:opts) do
      {
        path: '/dev/actions/check-in/789',
        access_token: 'abc123'
      }
    end
    let(:resp) do
      { check_in_status: 'completed' }.to_json
    end
    let(:faraday_response) { Faraday::Response.new(body: resp.to_json) }

    it 'returns a Faraday::Response' do
      allow_any_instance_of(ChipApi::Session).to receive(:retrieve).and_return('abc123')
      allow_any_instance_of(ChipApi::Request).to receive(:post).with(opts).and_return(faraday_response)

      expect(subject.build.create_check_in('789')).to eq({ data: Oj.load(faraday_response.body) })
    end
  end
end
