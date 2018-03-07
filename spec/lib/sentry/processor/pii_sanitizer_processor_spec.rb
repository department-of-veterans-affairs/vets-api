# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sentry::Processor::PIISanitizer do
  let(:client) { double('client') }
  let(:processor) { Sentry::Processor::PIISanitizer.new(client) }
  let(:result) { processor.process(data) }

  context 'with symbol keys' do
    let(:data) do
      {
        veteran_address: {
          city: 'Las Vegas',
          country: 'USA',
          postal_code: '91823',
          street: '1234 Street St.',
          state: 'NV'
        },
        json: '{"phone": "5035551234", "postalCode": 97850}',
        array_of_json: ['{"phone": "5035551234", "postalCode": 97850}'],
        gender: 'M',
        phone: '5035551234'
      }
    end

    it 'should filter address data' do
      result[:veteran_address].each_value { |v| expect(v).to eq('FILTERED') }
    end

    it 'should filter gender data' do
      expect(result[:gender]).to eq('FILTERED')
    end

    it 'should filter phone data' do
      expect(result[:phone]).to eq('FILTERED')
    end

    it 'should filter json blobs' do
      expect(result[:json]).to include('FILTERED')
    end

    it 'should filter arrays' do
      expect(result[:array_of_json].first).to include('FILTERED')
    end
  end

  context 'with string keys' do
    let(:data) do
      {
        'veteranAddress' => {
          'city' => 'Portland',
          'country' => 'USA',
          'postalCode' => '19391',
          'street' => '4321 Street St.',
          'state' => 'OR'
        },
        'json' => '{"gender": "F"}',
        'arrayOfJson' => ['{"phone": "5035551234", "postalCode": 97850}'],
        'gender' => 'F',
        'phone' => '5415551234'
      }
    end

    it 'should filter address data' do
      result['veteranAddress'].each_value { |v| expect(v).to eq('FILTERED') }
    end

    it 'should filter gender data' do
      expect(result['gender']).to eq('FILTERED')
    end

    it 'should filter phone data' do
      expect(result['phone']).to eq('FILTERED')
    end

    it 'should filter json blobs' do
      expect(result['json']).to include('FILTERED')
    end

    it 'should filter arrays' do
      expect(result['arrayOfJson'].first).to include('FILTERED')
    end
  end
end
