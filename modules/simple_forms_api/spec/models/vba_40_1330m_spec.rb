# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA401330m do
  it_behaves_like 'zip_code_is_us_based', %w[applicant_address]

  describe 'handle_attachments' do
    it 'saves the combined pdf when attachments exist' do
      original_pdf = double('HexaPDF::Document')
      attachment_pdf = double('HexaPDF::Document')
      pages_mock = double('HexaPDF::PageList')
      page_mock = double('HexaPDF::Page')
      original_file_path = 'original-file-path'
      persistent_attachment = double('PersistentAttachment')

      form = SimpleFormsApi::VBA401330m.new(
        {
          'veteran_supporting_documents' => [
            { 'confirmation_code' => 'test-guid-123' }
          ]
        }
      )

      allow(PersistentAttachment).to receive(:where).with(guid: ['test-guid-123']).and_return([persistent_attachment])
      allow(persistent_attachment).to receive(:to_pdf).and_return('attachment-path')
      allow(HexaPDF::Document).to receive(:open).with(original_file_path).and_return(original_pdf)
      allow(HexaPDF::Document).to receive(:open).with('attachment-path').and_return(attachment_pdf)

      allow(original_pdf).to receive(:import).with(page_mock).and_return(page_mock)
      allow(original_pdf).to receive(:pages).and_return(pages_mock)
      allow(attachment_pdf).to receive(:pages).and_return(pages_mock)

      allow(pages_mock).to receive(:each).and_yield(page_mock)
      allow(pages_mock).to receive(:<<)

      allow(original_pdf).to receive(:write).with(original_file_path, optimize: true)

      form.handle_attachments(original_file_path)

      expect(original_pdf).to have_received(:write).with(original_file_path, optimize: true)
      expect(pages_mock).to have_received(:<<).at_least(:once).with(page_mock)
    end

    it 'handles no attachments gracefully' do
      original_pdf = double('HexaPDF::Document')
      pages_mock = double('HexaPDF::PageList')
      original_file_path = 'original-file-path'

      form = SimpleFormsApi::VBA401330m.new({})

      allow(HexaPDF::Document).to receive(:open).with(original_file_path).and_return(original_pdf)
      allow(original_pdf).to receive(:pages).and_return(pages_mock)
      allow(original_pdf).to receive(:write).with(original_file_path, optimize: true)

      form.handle_attachments(original_file_path)

      expect(original_pdf).to have_received(:write).with(original_file_path, optimize: true)
    end
  end

  describe '#metadata' do
    let(:data) do
      {
        'veteran_full_name' => {
          'first' => 'John',
          'last' => 'Smith'
        },
        'veteran_id' => {
          'ssn' => '123456789',
          'va_file_number' => '987654321'
        },
        'applicant_address' => {
          'postal_code' => '97201'
        },
        'form_number' => '40-1330M'
      }
    end

    it 'returns the correct metadata structure' do
      form = described_class.new(data)
      metadata = form.metadata

      expect(metadata['veteranFirstName']).to eq 'John'
      expect(metadata['veteranLastName']).to eq 'Smith'
      expect(metadata['fileNumber']).to eq '987654321'
      expect(metadata['zipCode']).to eq '97201'
      expect(metadata['source']).to eq 'VA Platform Digital Forms'
      expect(metadata['docType']).to eq '40-1330M'
      expect(metadata['businessLine']).to eq 'NCA'
    end

    it 'uses SSN as fileNumber when va_file_number is not present' do
      data_without_file_number = data.dup
      data_without_file_number['veteran_id'].delete('va_file_number')

      form = described_class.new(data_without_file_number)
      metadata = form.metadata

      expect(metadata['fileNumber']).to eq '123456789'
    end
  end

  describe '#notification_first_name' do
    let(:data) do
      {
        'applicant_full_name' => {
          'first' => 'Jane',
          'last' => 'Doe'
        }
      }
    end

    it 'returns the first name to be used in notifications' do
      expect(described_class.new(data).notification_first_name).to eq 'Jane'
    end
  end

  describe '#notification_email_address' do
    let(:data) do
      { 'applicant_email' => 'jane.doe@example.com' }
    end

    it 'returns the email address to be used in notifications' do
      expect(described_class.new(data).notification_email_address).to eq 'jane.doe@example.com'
    end
  end

  describe '#track_user_identity' do
    let(:data) { { 'form_number' => '40-1330M' } }

    it 'increments StatsD and logs the submission' do
      form = described_class.new(data)
      confirmation_number = 'test-confirmation-123'

      expect(StatsD).to receive(:increment).with('api.simple_forms_api.40_1330m.submission')
      expect(Rails.logger).to receive(:info).with(
        'Simple forms api - 40-1330M submission',
        confirmation_number: confirmation_number
      )

      form.track_user_identity(confirmation_number)
    end
  end

  describe '#words_to_remove' do
    let(:data) do
      {
        'veteran_id' => {
          'ssn' => '123456789',
          'va_file_number' => '987654321'
        },
        'veteran_date_of_birth' => '1945-03-15',
        'veteran_date_of_death' => '2020-08-22',
        'applicant_address' => {
          'postal_code' => '97201-1234'
        },
        'applicant_phone' => '503-555-1234'
      }
    end

    it 'returns all sensitive data fragments' do
      form = described_class.new(data)
      words = form.words_to_remove

      # Check that it includes SSN fragments
      expect(words).to include('123', '45', '6789')
      # Check that it includes file number fragments
      expect(words).to include('987', '65', '4321')
      # Check that it includes date fragments
      expect(words).to include('1945', '03', '15')
      expect(words).to include('2020', '08', '22')
      # Check that it includes postal code fragments
      expect(words).to include('97201', '1234')
      # Check that it includes phone number fragments
      expect(words).to include('503', '555', '1234')
    end
  end
end
