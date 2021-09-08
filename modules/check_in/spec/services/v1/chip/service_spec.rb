# frozen_string_literal: true

require 'rails_helper'

describe V1::Chip::Service do
  subject { described_class }

  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:valid_check_in) { CheckIn::PatientCheckIn.build(uuid: id) }
  let(:invalid_check_in) { CheckIn::PatientCheckIn.build(uuid: '1234') }

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(valid_check_in)).to be_an_instance_of(V1::Chip::Service)
    end
  end

  describe '#create_check_in' do
    let(:opts) do
      {
        path: '/dev/actions/check-in/d602d9eb-9a31-484f-9637-13ab0b507e0d',
        access_token: 'abc123'
      }
    end
    let(:resp) { 'Checkin successful' }
    let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }

    it 'returns a Faraday::Response' do
      allow_any_instance_of(V1::Chip::Session).to receive(:retrieve).and_return('abc123')
      allow_any_instance_of(V1::Chip::Request).to receive(:post).with(opts).and_return(faraday_response)

      hsh = { data: faraday_response.body, status: faraday_response.status }

      expect(subject.build(valid_check_in).create_check_in).to eq(hsh)
    end
  end

  describe '#base_path' do
    it 'returns base_path' do
      expect(subject.build(valid_check_in).base_path).to eq('dev')
    end
  end
end
