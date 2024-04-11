# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::VAOS::BaseService do
  subject { described_class.new(patient_icn:) }

  let(:patient_icn) { '123' }
  let(:token) { 'test_token' }
  let(:request_id) { SecureRandom.uuid }

  describe '#config' do
    it 'returns an instance of Configuration' do
      expect(subject.config).to be_an_instance_of(CheckIn::VAOS::Configuration)
    end
  end

  describe '#headers' do
    before do
      allow_any_instance_of(CheckIn::Map::TokenService).to receive(:token).and_return(token)
      RequestStore.store['request_id'] = request_id
    end

    it 'returns correct headers' do
      expect(subject.headers).to eq({ 'Referer' => 'https://review-instance.va.gov',
                                      'X-VAMF-JWT' => token,
                                      'X-Request-ID' => request_id })
    end
  end

  describe '#referrer' do
    context 'when ends in .gov' do
      it 'returns the hostname with "vets" replaced with "va"' do
        allow(Settings).to receive(:hostname).and_return('veteran.apps.vets.gov')
        expect(subject.referrer).to eq('https://veteran.apps.va.gov')
      end
    end

    context 'when does not end in .gov' do
      it 'returns https://review-instance.va.gov' do
        expect(subject.referrer).to eq('https://review-instance.va.gov')
      end
    end
  end
end
