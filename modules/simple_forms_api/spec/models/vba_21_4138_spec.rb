# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA214138 do
  it_behaves_like 'zip_code_is_us_based', %w[mailing_address]

  describe '#desired_stamps' do
    let(:data) { { 'statement_of_truth_signature' => 'John Doe' } }

    it 'returns signature stamp with coordinates' do
      result = described_class.new(data).desired_stamps
      expect(result).to be_an(Array)
      expect(result.first[:coords]).to eq([[35, 220]])
      expect(result.first[:text]).to eq('John Doe')
      expect(result.first[:page]).to eq(1)
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
      expect(result.first[:page]).to eq(0)
      expect(result.last[:text]).to include('UTC')
      expect(result.last[:page]).to eq(0)
    end
  end

  describe '#metadata' do
    let(:data) do
      {
        'full_name' => { 'first' => 'John', 'last' => 'Doe' },
        'id_number' => { 'ssn' => '123456789' },
        'mailing_address' => { 'postal_code' => '12345' },
        'form_number' => '21-4138'
      }
    end

    it 'returns metadata hash with SSN' do
      result = described_class.new(data).metadata
      expect(result['veteranFirstName']).to eq('John')
      expect(result['veteranLastName']).to eq('Doe')
      expect(result['fileNumber']).to eq('123456789')
      expect(result['zipCode']).to eq('12345')
      expect(result['source']).to eq('VA Platform Digital Forms')
      expect(result['docType']).to eq('21-4138')
      expect(result['businessLine']).to eq('CMP')
    end

    it 'uses VA file number when available' do
      data['id_number'] = { 'va_file_number' => 'C12345678', 'ssn' => '123456789' }
      result = described_class.new(data).metadata
      expect(result['fileNumber']).to eq('C12345678')
    end

    it 'falls back to SSN when VA file number is blank' do
      data['id_number'] = { 'va_file_number' => '', 'ssn' => '123456789' }
      result = described_class.new(data).metadata
      expect(result['fileNumber']).to eq('123456789')
    end
  end

  describe '#notification_first_name' do
    let(:data) do
      {
        'full_name' => {
          'first' => 'John',
          'last' => 'Doe'
        }
      }
    end

    it 'returns the first name' do
      expect(described_class.new(data).notification_first_name).to eq('John')
    end
  end

  describe '#notification_email_address' do
    let(:data) { { 'email_address' => 'john@example.com' } }

    it 'returns the email address' do
      expect(described_class.new(data).notification_email_address).to eq('john@example.com')
    end
  end

  describe '#overflow_pdf' do
    context 'when statement is within the character limit' do
      let(:data) do
        {
          'statement' => 'a' * 3682,
          'full_name' => { 'first' => 'John', 'last' => 'Doe' },
          'id_number' => { 'ssn' => '123456789' }
        }
      end

      it 'returns nil' do
        result = described_class.new(data).overflow_pdf
        expect(result).to be_nil
      end
    end

    context 'when statement exceeds the character limit' do
      let(:data) do
        {
          'statement' => 'a' * 4000,
          'full_name' => { 'first' => 'Jane', 'last' => 'Smith' },
          'id_number' => { 'ssn' => '987654321' }
        }
      end

      it 'creates a PDF file' do
        result = described_class.new(data).overflow_pdf
        expect(result).to be_a(String)
        expect(File.exist?(result)).to be true

        # Cleanup
        File.delete(result) if result && File.exist?(result)
      end
    end

    context 'when statement is exactly at the limit' do
      let(:data) do
        {
          'statement' => 'a' * 3685,
          'full_name' => { 'first' => 'John', 'last' => 'Doe' },
          'id_number' => { 'ssn' => '123456789' }
        }
      end

      it 'returns nil' do
        result = described_class.new(data).overflow_pdf
        expect(result).to be_nil
      end
    end

    context 'when statement is one character over the limit' do
      let(:data) do
        {
          'statement' => 'a' * 3687,
          'full_name' => { 'first' => 'John', 'last' => 'Doe' },
          'id_number' => { 'ssn' => '123456789' }
        }
      end

      it 'returns a file path' do
        result = described_class.new(data).overflow_pdf
        expect(result).not_to be_nil

        # Cleanup
        File.delete(result) if result && File.exist?(result)
      end
    end

    context 'when statement is nil' do
      let(:data) do
        {
          'statement' => nil,
          'full_name' => { 'first' => 'John', 'last' => 'Doe' },
          'id_number' => { 'ssn' => '123456789' }
        }
      end

      it 'returns nil' do
        result = described_class.new(data).overflow_pdf
        expect(result).to be_nil
      end
    end
  end

  describe 'constants' do
    it 'defines REMARKS_SLICE_1' do
      expect(described_class::REMARKS_SLICE_1).to eq(0..1510)
    end

    it 'defines REMARKS_SLICE_2' do
      expect(described_class::REMARKS_SLICE_2).to eq(1511..3685)
    end

    it 'defines ALLOTTED_REMARKS_LAST_INDEX' do
      expect(described_class::ALLOTTED_REMARKS_LAST_INDEX).to eq(3685)
    end
  end
end
