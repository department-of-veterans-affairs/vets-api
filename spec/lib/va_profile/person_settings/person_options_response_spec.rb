# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/person_settings/person_options_response'

RSpec.describe VAProfile::PersonSettings::PersonOptionsResponse do
  describe '.from' do
    subject { described_class.from(raw_response) }

    let(:response_body) { nil }
    let(:status_code) { 200 }
    let(:raw_response) do
      double('Faraday::Response',
             status: status_code,
             body: response_body)
    end

    it 'initializes with the correct status code' do
      expect(subject.status).to eq(status_code)
    end

    context 'with person options data' do
      let(:response_body) do
        {
          'tx_audit_id' => 'fake-transaction-id-xyz',
          'status' => 'COMPLETED_SUCCESS',
          'bios' => [
            {
              'source_date' => '2025-11-25T00:00:00Z',
              'originating_source_system' => 'TEST_SYSTEM',
              'source_system_user' => 'test-user-123',
              'person_option_id' => 123,
              'effective_start_date' => '2025-11-25T00:00:00Z',
              'option_id' => 30,
              'option_label' => 'Does Not Prefer Assistance',
              'option_type_code' => 'STRING',
              'option_value_string' => 'NO_ASSISTANCE',
              'item_id' => 4
            },
            {
              'source_date' => '2025-11-26T00:00:00Z',
              'originating_source_system' => 'TEST_SYSTEM',
              'source_system_user' => 'test-user-123',
              'person_option_id' => 456,
              'effective_start_date' => '2025-11-26T00:00:00Z',
              'option_id' => 5,
              'option_label' => 'Email',
              'option_type_code' => 'STRING',
              'option_value_string' => 'EMAIL',
              'item_id' => 1
            }
          ]
        }
      end

      it 'creates PersonOption instances from bios array' do
        expect(subject.person_options).to be_an(Array)
        expect(subject.person_options.length).to eq(2)
        expect(subject.person_options).to all(be_a(VAProfile::Models::PersonOption))
      end
    end

    context 'with empty bios array' do
      let(:response_body) do
        {
          'tx_audit_id' => 'fake-transaction-id-xyz',
          'status' => 'COMPLETED_SUCCESS',
          'bios' => []
        }
      end

      it 'returns empty person_options array' do
        expect(subject.person_options).to eq([])
      end

      it 'sets the correct HTTP status' do
        expect(subject.status).to eq(200)
      end
    end

    context 'with nil response body' do
      let(:raw_response) { nil }

      it 'returns empty person_options array' do
        expect(subject.person_options).to eq([])
      end

      it 'handles nil status gracefully' do
        expect(subject.status).to be_nil
      end
    end
  end
end
