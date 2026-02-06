# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA401330m do
  it_behaves_like 'zip_code_is_us_based', %w[applicant_address]

  describe '#get_attachments' do
    it 'returns additional_address PDF when additional_address is present' do
      form = SimpleFormsApi::VBA401330m.new(
        {
          'additional_address' => {
            'street' => '123 Main St',
            'city' => 'Portland',
            'state' => 'OR',
            'postal_code' => '97201',
            'country' => 'USA'
          }
        }
      )

      pdf_filler = double('SimpleFormsApi::PdfFiller')
      allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(pdf_filler)
      allow(pdf_filler).to receive(:generate).and_return('/tmp/additional_address.pdf')

      attachments = form.send(:get_attachments)

      expect(attachments).to include('/tmp/additional_address.pdf')
    end

    it 'returns PersistentAttachment PDFs when veteran_supporting_documents are present' do
      persistent_attachment = double('PersistentAttachment')
      allow(PersistentAttachment).to receive(:where).with(guid: ['test-guid-123']).and_return([persistent_attachment])
      allow(persistent_attachment).to receive(:to_pdf).and_return('/tmp/attachment.pdf')

      form = SimpleFormsApi::VBA401330m.new(
        {
          'veteran_supporting_documents' => [
            { 'confirmation_code' => 'test-guid-123' }
          ]
        }
      )

      attachments = form.send(:get_attachments)

      expect(attachments).to include('/tmp/attachment.pdf')
    end

    it 'returns both additional_address and supporting document PDFs' do
      persistent_attachment = double('PersistentAttachment')
      allow(PersistentAttachment).to receive(:where).with(guid: ['test-guid-123']).and_return([persistent_attachment])
      allow(persistent_attachment).to receive(:to_pdf).and_return('/tmp/attachment.pdf')

      pdf_filler = double('SimpleFormsApi::PdfFiller')
      allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(pdf_filler)
      allow(pdf_filler).to receive(:generate).and_return('/tmp/additional_address.pdf')

      form = SimpleFormsApi::VBA401330m.new(
        {
          'additional_address' => {
            'street' => '123 Main St',
            'city' => 'Portland',
            'state' => 'OR',
            'postal_code' => '97201',
            'country' => 'USA'
          },
          'veteran_supporting_documents' => [
            { 'confirmation_code' => 'test-guid-123' }
          ]
        }
      )

      attachments = form.send(:get_attachments)

      expect(attachments).to include('/tmp/additional_address.pdf')
      expect(attachments).to include('/tmp/attachment.pdf')
      expect(attachments.count).to eq(2)
    end

    it 'returns empty array when no attachments are present' do
      form = SimpleFormsApi::VBA401330m.new({})

      attachments = form.send(:get_attachments)

      expect(attachments).to eq([])
    end
  end

  describe '#fill_pdf_with_additional_address' do
    it 'generates PDF with additional_address data' do
      form_data = {
        'additional_address' => {
          'street' => '456 Oak Ave',
          'street2' => 'Apt 2B',
          'city' => 'Seattle',
          'state' => 'WA',
          'postal_code' => '98101',
          'country' => 'USA'
        },
        'applicant_full_name' => {
          'first' => 'Jane',
          'last' => 'Smith'
        }
      }

      form = SimpleFormsApi::VBA401330m.new(form_data)
      pdf_filler = double('SimpleFormsApi::PdfFiller')

      expect(SimpleFormsApi::PdfFiller).to receive(:new).with(
        form_number: 'vba_40_1330m',
        form: instance_of(SimpleFormsApi::VBA401330m),
        name: 'vba_40_1330m_additional_address'
      ).and_return(pdf_filler)
      expect(pdf_filler).to receive(:generate).and_return('/tmp/additional_address.pdf')

      result = form.send(:fill_pdf_with_additional_address)

      expect(result).to eq('/tmp/additional_address.pdf')
    end

    it 'maps additional_address to applicant_address for PDF generation' do
      form_data = {
        'additional_address' => {
          'street' => '789 Pine St',
          'city' => 'Portland',
          'state' => 'OR',
          'postal_code' => '97202',
          'country' => 'USA'
        }
      }

      form = SimpleFormsApi::VBA401330m.new(form_data)
      pdf_filler = double('SimpleFormsApi::PdfFiller')

      allow(SimpleFormsApi::PdfFiller).to receive(:new) do |args|
        expect(args[:form].data['applicant_address']['street']).to eq('789 Pine St')
        expect(args[:form].data['applicant_address']['city']).to eq('Portland')
        expect(args[:form].data['applicant_address']['state']).to eq('OR')
        expect(args[:form].data['applicant_address']['postal_code']).to eq('97202')
        expect(args[:form].data['applicant_address']['country']).to eq('USA')
        pdf_filler
      end
      allow(pdf_filler).to receive(:generate).and_return('/tmp/additional_address.pdf')

      form.send(:fill_pdf_with_additional_address)
    end
  end

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

      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(original_file_path).and_return(true)

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

      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(original_file_path).and_return(true)

      form.handle_attachments(original_file_path)

      expect(original_pdf).to have_received(:write).with(original_file_path, optimize: true)
    end

    it 'handles additional_address PDF as attachment' do
      original_pdf = double('HexaPDF::Document')
      additional_pdf = double('HexaPDF::Document')
      pages_mock = double('HexaPDF::PageList')
      page_mock = double('HexaPDF::Page')
      original_file_path = 'original-file-path'

      form = SimpleFormsApi::VBA401330m.new(
        {
          'additional_address' => {
            'street' => '123 Main St',
            'city' => 'Portland',
            'state' => 'OR',
            'postal_code' => '97201',
            'country' => 'USA'
          }
        }
      )

      pdf_filler = double('SimpleFormsApi::PdfFiller')
      allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(pdf_filler)
      allow(pdf_filler).to receive(:generate).and_return('/tmp/additional_address.pdf')

      allow(HexaPDF::Document).to receive(:open).with(original_file_path).and_return(original_pdf)
      allow(HexaPDF::Document).to receive(:open).with('/tmp/additional_address.pdf').and_return(additional_pdf)

      allow(original_pdf).to receive(:import).with(page_mock).and_return(page_mock)
      allow(original_pdf).to receive(:pages).and_return(pages_mock)
      allow(additional_pdf).to receive(:pages).and_return(pages_mock)

      allow(pages_mock).to receive(:each).and_yield(page_mock)
      allow(pages_mock).to receive(:<<)

      allow(original_pdf).to receive(:write).with(original_file_path, optimize: true)

      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(original_file_path).and_return(true)

      form.handle_attachments(original_file_path)

      expect(original_pdf).to have_received(:write).with(original_file_path, optimize: true)
      expect(pages_mock).to have_received(:<<).at_least(:once).with(page_mock)
    end

    it 'logs error and raises when attachment loading fails' do
      original_pdf = double('HexaPDF::Document')
      pages_mock = double('HexaPDF::PageList')
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
      allow(persistent_attachment).to receive(:to_pdf).and_return('invalid-path')
      allow(HexaPDF::Document).to receive(:open).with(original_file_path).and_return(original_pdf)
      allow(HexaPDF::Document).to receive(:open).with('invalid-path').and_raise(StandardError, 'File not found')

      allow(original_pdf).to receive(:pages).and_return(pages_mock)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(original_file_path).and_return(true)

      expect(Rails.logger).to receive(:error).with(
        'Simple forms api - failed to load attachment for 40-1330M',
        hash_including(message: 'File not found')
      )

      expect { form.handle_attachments(original_file_path) }.to raise_error(StandardError, 'File not found')
    end

    it 'raises ArgumentError when file_path is nil' do
      form = SimpleFormsApi::VBA401330m.new({})

      expect { form.handle_attachments(nil) }.to raise_error(ArgumentError, 'file_path cannot be nil')
    end

    it 'raises ArgumentError when file_path does not exist' do
      form = SimpleFormsApi::VBA401330m.new({})
      non_existent_path = '/non/existent/path.pdf'

      allow(File).to receive(:exist?).with(non_existent_path).and_return(false)

      expect { form.handle_attachments(non_existent_path) }.to raise_error(
        ArgumentError,
        "file_path does not exist: #{non_existent_path}"
      )
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
        { confirmation_number: }
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
