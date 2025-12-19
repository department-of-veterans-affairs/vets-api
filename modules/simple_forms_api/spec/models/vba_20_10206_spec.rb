# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA2010206 do
  it_behaves_like 'zip_code_is_us_based', %w[address]

  describe '#notification_first_name' do
    let(:data) do
      {
        'full_name' => {
          'first' => 'Veteran',
          'last' => 'Eteranvay'
        }
      }
    end

    it 'returns the first name to be used in notifications' do
      expect(described_class.new(data).notification_first_name).to eq 'Veteran'
    end
  end

  describe '#notification_email_address' do
    let(:data) do
      { 'email_address' => 'a@b.com' }
    end

    it 'returns the email address to be used in notifications' do
      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end

  describe '#metadata' do
    let(:data) do
      {
        'full_name' => { 'first' => 'John', 'last' => 'Doe' },
        'citizen_id' => { 'ssn' => '123456789' },
        'address' => { 'postal_code' => '12345' },
        'form_number' => '20-10206'
      }
    end

    it 'returns metadata hash with citizen SSN' do
      result = described_class.new(data).metadata
      expect(result['veteranFirstName']).to eq('John')
      expect(result['veteranLastName']).to eq('Doe')
      expect(result['fileNumber']).to eq('123456789')
      expect(result['zipCode']).to eq('12345')
      expect(result['source']).to eq('VA Platform Digital Forms')
      expect(result['docType']).to eq('20-10206')
      expect(result['businessLine']).to eq('CMP')
    end

    it 'uses VA file number when SSN not available' do
      data['citizen_id'] = { 'va_file_number' => 'C12345678' }
      result = described_class.new(data).metadata
      expect(result['fileNumber']).to eq('C12345678')
    end

    it 'uses non-citizen ARN when citizen ID not available' do
      data.delete('citizen_id')
      data['non_citizen_id'] = { 'arn' => 'A123456789' }
      result = described_class.new(data).metadata
      expect(result['fileNumber']).to eq('A123456789')
    end
  end

  describe '#words_to_remove' do
    let(:data) do
      {
        'citizen_id' => { 'ssn' => '123456789' },
        'address' => { 'postal_code' => '12345-6789' },
        'date_of_birth' => '1990-01-15',
        'home_phone' => '555-123-4567'
      }
    end

    it 'returns array of words to remove' do
      result = described_class.new(data).words_to_remove
      expect(result).to be_an(Array)
      expect(result).to include('123', '45', '6789')
      expect(result).to include('12345', '6789')
      expect(result).to include('1990', '01', '15')
      expect(result).to include('555', '123', '4567')
    end
  end

  describe '#desired_stamps' do
    let(:data) { {} }

    it 'returns empty array' do
      expect(described_class.new(data).desired_stamps).to eq([])
    end
  end

  describe '#submission_date_stamps' do
    let(:data) { {} }
    let(:timestamp) { Time.zone.parse('2023-05-15 10:30:00 UTC') }

    it 'returns submission date stamps' do
      result = described_class.new(data).submission_date_stamps(timestamp)
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first[:text]).to eq('Application Submitted:')
      expect(result.first[:page]).to eq(1)
      expect(result.last[:text]).to include('UTC')
      expect(result.last[:page]).to eq(1)
    end
  end

  describe '#track_user_identity' do
    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
    end

    context 'when tracking the submitter identity' do
      let(:data) { { 'preparer_type' => 'veteran' } }

      it 'tracks user identity and logs information' do
        described_class.new(data).track_user_identity('ABC123')

        expect(StatsD).to have_received(:increment).with('api.simple_forms_api.20_10206.veteran')
        expect(Rails.logger).to have_received(:info).with(
          'Simple forms api - 20-10206 submission user identity',
          identity: 'veteran',
          confirmation_number: 'ABC123'
        )
      end
    end

    context 'when record selections are provided' do
      let(:data) do
        {
          'preparer_type' => 'veteran',
          'record_selections' => {
            'DD214' => true,
            'c_file' => false,
            'financial' => true
          }
        }
      end

      it 'increments statsd for each selected record type' do
        described_class.new(data).track_user_identity('ABC123')

        expect(StatsD).to have_received(:increment).with(
          'api.simple_forms_api.20_10206.record_type',
          tags: ['record_type:dd214']
        )
        expect(StatsD).to have_received(:increment).with(
          'api.simple_forms_api.20_10206.record_type',
          tags: ['record_type:financial']
        )
        expect(StatsD).not_to have_received(:increment).with(
          'api.simple_forms_api.20_10206.record_type',
          tags: ['record_type:c-file']
        )
      end
    end

    context 'when record selections are missing' do
      let(:data) { { 'preparer_type' => 'veteran', 'record_selections' => nil } }

      it 'does not increment record type metrics' do
        described_class.new(data).track_user_identity('ABC123')

        expect(StatsD).not_to have_received(:increment).with(
          'api.simple_forms_api.20_10206.record_type',
          tags: anything
        )
      end
    end

    context 'when record selections are empty' do
      let(:data) { { 'preparer_type' => 'veteran', 'record_selections' => {} } }

      it 'does not increment record type metrics' do
        described_class.new(data).track_user_identity('ABC123')

        expect(StatsD).not_to have_received(:increment).with(
          'api.simple_forms_api.20_10206.record_type',
          tags: anything
        )
      end
    end

    context 'when record selections contain unknown keys' do
      let(:data) do
        {
          'preparer_type' => 'veteran',
          'record_selections' => {
            'unknown_key' => true,
            'dd214' => true
          }
        }
      end

      it 'only tracks the known record types' do
        described_class.new(data).track_user_identity('ABC123')

        expect(StatsD).to have_received(:increment).with(
          'api.simple_forms_api.20_10206.record_type',
          tags: ['record_type:dd214']
        )
        expect(StatsD).not_to have_received(:increment).with(
          'api.simple_forms_api.20_10206.record_type',
          tags: ['record_type:unknown_key']
        )
      end
    end
  end
end
