# frozen_string_literal: true

require 'rails_helper'
require 'carma/models/veteran'

RSpec.describe CARMA::Models::Veteran, type: :model do
  describe '#icn' do
    it 'is accessible' do
      subject.icn = 'ABCD1234'
      expect(subject.icn).to eq('ABCD1234')
    end
  end

  describe '#is_veteran' do
    it 'is accessible' do
      subject.is_veteran = true
      expect(subject.is_veteran).to eq(true)
    end
  end

  describe '::new' do
    it 'is :is_veteran, :icn' do
      subject = described_class.new(icn: 'ABCD1234', is_veteran: true)
      expect(subject.icn).to eq('ABCD1234')
      expect(subject.is_veteran).to eq(true)
    end
  end

  describe '::request_payload_keys' do
    it 'inherits fron Base' do
      expect(described_class.ancestors).to include(CARMA::Models::Base)
    end

    it 'sets request_payload_keys' do
      expect(described_class.request_payload_keys).to eq(%i[icn is_veteran])
    end
  end

  describe '#to_request_payload' do
    it 'can receive :to_request_payload' do
      instance = described_class.new icn: 'ABCD1234', is_veteran: true

      expect(instance.to_request_payload).to eq(
        {
          'icn' => 'ABCD1234',
          'isVeteran' => true
        }
      )
    end
  end
end
