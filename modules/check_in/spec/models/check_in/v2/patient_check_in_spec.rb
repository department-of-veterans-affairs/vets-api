# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::PatientCheckIn do
  subject { described_class }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:patient_check_in) { subject.build }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of PatientCheckIn' do
      expect(patient_check_in).to be_an_instance_of(CheckIn::V2::PatientCheckIn)
    end
  end

  describe 'attributes' do
    it 'responds to check_in' do
      expect(patient_check_in.respond_to?(:check_in)).to be(true)
    end

    it 'responds to data' do
      expect(patient_check_in.respond_to?(:data)).to be(true)
    end

    it 'responds to settings' do
      expect(patient_check_in.respond_to?(:settings)).to be(true)
    end

    it 'gets redis_session_prefix from settings' do
      expect(patient_check_in.redis_session_prefix).to eq('check_in_lorota_v2')
    end

    it 'gets redis_token_expiry from settings' do
      expect(patient_check_in.redis_token_expiry).to eq(43_200)
    end
  end

  describe 'check_in_type' do
    let(:uuid) { Faker::Internet.uuid }
    let(:check_in) { double('Session', uuid:, check_in_type: 'preCheckIn') }

    it 'delegates check_in_type to check_in' do
      patient_check_in = subject.build(check_in:)

      expect(patient_check_in.check_in_type).to eq('preCheckIn')
    end
  end

  describe '#unauthorized_message' do
    let(:uuid) { Faker::Internet.uuid }
    let(:check_in) { double('Session', uuid:) }
    let(:data) { double('FaradayResponse', status: 200, body: {}) }
    let(:resp) { { permissions: 'read.none', status: 'success', uuid: } }

    it 'returns a hashed response' do
      patient_check_in_with_data = subject.build(data:, check_in:)

      expect(patient_check_in_with_data.unauthorized_message).to eq(resp)
    end
  end

  describe '#error_status?' do
    let(:data) { double('FaradayResponse', status: 401, body: {}) }

    it 'returns true' do
      patient_check_in_with_data = subject.build(data:, check_in: nil)

      expect(patient_check_in_with_data.error_status?).to eq(true)
    end
  end

  describe '#error_message' do
    let(:uuid) { Faker::Internet.uuid }
    let(:check_in) { double('Session', uuid:) }
    let(:data) { double('FaradayResponse', status: 403, body: { error: 'forbidden' }.to_json) }
    let(:resp) { { error: true, message: { 'error' => 'forbidden' }, status: 403 } }

    it 'returns an error message' do
      patient_check_in_with_data = subject.build(data:, check_in: nil)

      expect(patient_check_in_with_data.error_message).to eq(resp)
    end
  end
end
