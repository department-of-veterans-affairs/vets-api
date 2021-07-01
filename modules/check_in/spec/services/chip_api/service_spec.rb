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
    let(:id) { '123abc' }

    it 'returns a Faraday::Response' do
      allow_any_instance_of(ChipApi::Request).to receive(:get).with(id).and_return(faraday_response)

      expect(subject.build.get_check_in(id)).to eq({ data: nil })
    end
  end

  describe '#create_check_in' do
    let(:data) do
      {
        id: 'abc123',
        check_in_data: {}
      }
    end

    it 'returns a Faraday::Response' do
      allow_any_instance_of(ChipApi::Request).to receive(:post).with(data).and_return(faraday_response)

      expect(subject.build.create_check_in(data)).to eq({ data: nil })
    end
  end
end
