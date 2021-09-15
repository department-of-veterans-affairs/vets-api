# frozen_string_literal: true

require 'rails_helper'

describe V1::Lorota::BasicService do
  subject { described_class }

  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:valid_check_in) { CheckIn::PatientCheckIn.build(uuid: id) }
  let(:invalid_check_in) { CheckIn::PatientCheckIn.build(uuid: '1234') }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(check_in: valid_check_in)).to be_an_instance_of(V1::Lorota::BasicService)
    end
  end

  describe '#get_or_create_token' do
    it 'returns data from redis' do
      allow_any_instance_of(V1::Lorota::BasicSession).to receive(:from_redis).and_return('123abc')

      hsh = {
        data: {
          permissions: 'read.basic',
          uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
          status: 'success',
          jwt: '123abc'
        },
        status: 200
      }

      expect(subject.build(check_in: valid_check_in).get_or_create_token).to eq(hsh)
    end

    it 'returns data from lorota' do
      allow_any_instance_of(V1::Lorota::BasicSession).to receive(:from_redis).and_return(nil)
      allow_any_instance_of(V1::Lorota::BasicSession).to receive(:from_lorota).and_return('abc123')

      hsh = {
        data: {
          permissions: 'read.basic',
          uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
          status: 'success',
          jwt: 'abc123'
        },
        status: 200
      }

      expect(subject.build(check_in: valid_check_in).get_or_create_token).to eq(hsh)
    end
  end

  describe '#get_check_in' do
    let(:data) do
      Faraday::Response.new(body: '{"foo":"bar"}', status: 200)
    end

    it 'return check-in data' do
      allow_any_instance_of(V1::Lorota::BasicSession).to receive(:from_redis).and_return('123abc')
      allow_any_instance_of(V1::Lorota::Request).to receive(:get).with(anything).and_return(data)

      expect(subject.build(check_in: valid_check_in).get_check_in).to eq({ 'foo' => 'bar' })
    end
  end

  describe '#base_path' do
    it 'returns base_path' do
      expect(subject.build(check_in: valid_check_in).base_path).to eq('dev')
    end
  end

  describe '#permissions' do
    it 'returns permissions' do
      expect(subject.build(check_in: valid_check_in).permissions).to eq('read.basic')
    end
  end

  describe '#format_data' do
    it 'returns formatted data' do
      hsh = {
        data: {
          permissions: 'read.basic',
          uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
          status: 'success',
          jwt: '123'
        },
        status: 200
      }

      expect(subject.build(check_in: valid_check_in).format_data('123')).to eq(hsh)
    end
  end
end
