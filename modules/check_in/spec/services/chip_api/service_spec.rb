# frozen_string_literal: true

require 'rails_helper'

describe ChipApi::Service do
  subject { described_class }

  let(:faraday_response) { Faraday::Response.new }

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build).to be_an_instance_of(ChipApi::Service)
    end
  end

  describe '#get_check_in' do
    Timecop.freeze(Time.zone.now)

    let(:id) { '123abc' }
    let(:resp) do
      {
        data: {
          uuid: '123abc',
          appointment_time: Time.zone.now.to_s,
          facility_name: 'Acme VA',
          clinic_name: 'Green Team Clinic1',
          clinic_phone: '555-555-5555'
        }
      }
    end

    it 'returns a Faraday::Response' do
      allow_any_instance_of(ChipApi::Request).to receive(:get).with(id).and_return(faraday_response)

      expect(subject.build.get_check_in(id)).to eq(resp)
    end

    Timecop.return
  end

  describe '#create_check_in' do
    let(:data) do
      {
        id: 'abc123',
        check_in_data: {}
      }
    end
    let(:resp) do
      { data: { check_in_status: 'completed' } }
    end

    it 'returns a Faraday::Response' do
      allow_any_instance_of(ChipApi::Request).to receive(:post).with(data).and_return(faraday_response)

      expect(subject.build.create_check_in(data)).to eq(resp)
    end
  end
end
