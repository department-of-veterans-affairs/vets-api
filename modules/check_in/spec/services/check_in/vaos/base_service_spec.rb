# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::VAOS::BaseService do
  subject { described_class.build(check_in_session:) }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in_session) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:patient_icn) { '123' }
  let(:token) { 'test_token' }
  let(:request_id) { SecureRandom.uuid }

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe '#initialize' do
    before do
      allow_any_instance_of(V2::Lorota::RedisClient).to receive(:icn).with(uuid:)
                                                                     .and_return(patient_icn)
    end

    it 'has a check_in_session object' do
      expect(subject.check_in_session).to be_a(CheckIn::V2::Session)
    end

    it 'has a patient icn' do
      expect(subject.patient_icn).to eq(patient_icn)
    end
  end

  describe '#config' do
    it 'returns an instance of Configuration' do
      expect(subject.config).to be_an_instance_of(CheckIn::VAOS::Configuration)
    end
  end

  describe '#headers' do
    before do
      RequestStore.store['request_id'] = request_id

      allow_any_instance_of(CheckIn::Map::TokenService).to receive(:token).and_return(token)
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
