# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA400247 do
  it_behaves_like 'zip_code_is_us_based', %w[applicant_address]

  describe '#metadata' do
    it 'returns correct metadata hash' do
      data = {
        'veteran_full_name' => { 'first' => 'John', 'last' => 'Doe' },
        'veteran_id' => { 'va_file_number' => '123456789', 'ssn' => '987654321' },
        'applicant_address' => { 'postal_code' => '12345' },
        'form_number' => '40-0247'
      }
      result = described_class.new(data).metadata
      expect(result['veteranFirstName']).to eq 'John'
      expect(result['veteranLastName']).to eq 'Doe'
      expect(result['fileNumber']).to eq '123456789'
      expect(result['zipCode']).to eq '12345'
      expect(result['source']).to eq 'VA Platform Digital Forms'
      expect(result['docType']).to eq '40-0247'
      expect(result['businessLine']).to eq 'CMP'
    end

    it 'falls back to ssn if va_file_number is missing' do
      data = {
        'veteran_full_name' => { 'first' => 'John', 'last' => 'Doe' },
        'veteran_id' => { 'ssn' => '987654321' },
        'applicant_address' => { 'postal_code' => '12345' },
        'form_number' => '40-0247'
      }
      result = described_class.new(data).metadata
      expect(result['fileNumber']).to eq '987654321'
    end
  end

  describe '#veteran_name' do
    it 'returns full veteran name' do
      data = { 'veteran_full_name' => { 'first' => 'John', 'middle' => 'Q', 'last' => 'Doe' } }
      expect(described_class.new(data).veteran_name).to eq 'John Q Doe'
    end

    it 'handles missing middle name' do
      data = { 'veteran_full_name' => { 'first' => 'John', 'last' => 'Doe' } }
      expect(described_class.new(data).veteran_name).to eq 'John  Doe'
    end
  end

  describe '#applicant_name' do
    it 'returns full applicant name' do
      data = { 'applicant_full_name' => { 'first' => 'Jane', 'middle' => 'R', 'last' => 'Smith' } }
      expect(described_class.new(data).applicant_name).to eq 'Jane R Smith'
    end

    it 'handles missing middle name' do
      data = { 'applicant_full_name' => { 'first' => 'Jane', 'last' => 'Smith' } }
      expect(described_class.new(data).applicant_name).to eq 'Jane  Smith'
    end
  end

  describe '#applicant_address' do
    it 'returns formatted address' do
      data = {
        'applicant_address' => {
          'street' => '123 Main St',
          'street2' => 'Apt 4',
          'city' => 'Springfield',
          'state' => 'IL',
          'postal_code' => '62704',
          'country' => 'USA'
        }
      }
      expect(described_class.new(data).applicant_address).to include('123 Main St, Apt 4')
      expect(described_class.new(data).applicant_address)
        .to include('Springfield, IL 62704 USA')
    end

    it 'handles missing fields' do
      data = { 'applicant_address' => {} }
      expect(described_class.new(data).applicant_address).to include(', \n,  ')
    end
  end

  describe '#zip_code_is_us_based' do
    it 'returns true if country is USA' do
      data = { 'applicant_address' => { 'country' => 'USA' } }
      expect(described_class.new(data).zip_code_is_us_based).to be true
    end

    it 'returns false if country is not USA' do
      data = { 'applicant_address' => { 'country' => 'CAN' } }
      expect(described_class.new(data).zip_code_is_us_based).to be false
    end

    it 'returns false if country is missing' do
      data = { 'applicant_address' => {} }
      expect(described_class.new(data).zip_code_is_us_based).to be false
    end
  end

  describe '#notification_first_name' do
    let(:data) do
      {
        'applicant_full_name' => {
          'first' => 'Applicant',
          'last' => 'Eteranvay'
        }
      }
    end

    it 'returns the first name to be used in notifications' do
      expect(described_class.new(data).notification_first_name).to eq 'Applicant'
    end
  end

  describe '#notification_email_address' do
    let(:data) { { 'applicant_email' => 'a@b.com' } }

    it 'returns the email address to be used in notifications' do
      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end

  describe '#desired_stamps' do
    it 'returns empty array' do
      expect(described_class.new({}).desired_stamps).to eq []
    end
  end

  describe '#submission_date_stamps' do
    it 'returns empty array' do
      expect(described_class.new({}).submission_date_stamps(nil)).to eq []
    end
  end

  describe '#track_user_identity' do
    it 'does nothing (no-op)' do
      expect { described_class.new({}).track_user_identity('123') }.not_to raise_error
    end
  end

  describe '#words_to_remove' do
    it 'returns an array' do
      expect(described_class.new({}).words_to_remove).to be_a(Array)
    end
  end

  describe '#handle_attachments' do
    it 'writes merged pdf even if no attachments' do
      file_path = 'original-file-path'
      pdf = double('HexaPDF::Document', pages: [], write: true)
      allow(HexaPDF::Document).to receive(:open).with(file_path).and_return(pdf)
      expect(pdf).to receive(:write).with(file_path, optimize: true)
      described_class.new({}).handle_attachments(file_path)
    end

    it 'merges attachments if present' do
      file_path = 'original-file-path'
      attachment_path = 'attachment.pdf'
      pdf = double('HexaPDF::Document', pages: [], write: true, import: true)
      attachment_pdf = double('HexaPDF::Document', pages: [double('HexaPDF::Page')])
      allow(HexaPDF::Document).to receive(:open).with(file_path).and_return(pdf)
      allow(HexaPDF::Document).to receive(:open).with(attachment_path).and_return(attachment_pdf)
      allow_any_instance_of(SimpleFormsApi::VBA400247).to receive(:get_attachments).and_return([attachment_path])
      expect(pdf).to receive(:import).at_least(:once)
      expect(pdf).to receive(:write).with(file_path, optimize: true)
      described_class.new({}).handle_attachments(file_path)
    end

    it 'handles additional address attachment' do
      file_path = 'original-file-path'
      filler = double('SimpleFormsApi::PdfFiller', generate: 'filled.pdf')
      pdf = double('HexaPDF::Document', pages: [], write: true, import: true)
      attachment_pdf = double('HexaPDF::Document', pages: [double('HexaPDF::Page')])
      allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(filler)
      allow(HexaPDF::Document).to receive(:open).with(file_path).and_return(pdf)
      allow(HexaPDF::Document).to receive(:open).with('filled.pdf').and_return(attachment_pdf)
      allow_any_instance_of(SimpleFormsApi::VBA400247).to receive(:get_attachments).and_return(['filled.pdf'])
      expect(pdf).to receive(:import).at_least(:once)
      expect(pdf).to receive(:write).with(file_path, optimize: true)
      data = {
        'additional_address' => {
          'street' => '123 Fake St.',
          'city' => 'Fakesville',
          'state' => 'FS',
          'postal_code' => '12345',
          'country' => 'USA'
        }
      }
      described_class.new(data).handle_attachments(file_path)
    end

    it 'handles supporting document attachments' do
      file_path = 'original-file-path'
      pdf = double('HexaPDF::Document', pages: [], write: true, import: true)
      attachment_pdf = double('HexaPDF::Document', pages: [double('HexaPDF::Page')])
      attachment = double('PersistentAttachment', to_pdf: 'pdf_path')
      allow(PersistentAttachment).to receive(:where).with(guid: ['abc']).and_return([attachment])
      allow(HexaPDF::Document).to receive(:open).with(file_path).and_return(pdf)
      allow(HexaPDF::Document).to receive(:open).with('pdf_path').and_return(attachment_pdf)
      allow_any_instance_of(SimpleFormsApi::VBA400247).to receive(:get_attachments).and_return(['pdf_path'])
      expect(pdf).to receive(:import).at_least(:once)
      expect(pdf).to receive(:write).with(file_path, optimize: true)
      data = {
        'veteran_supporting_documents' => [
          { 'confirmation_code' => 'abc' }
        ]
      }
      described_class.new(data).handle_attachments(file_path)
    end
  end

  describe 'private #get_attachments' do
    it 'returns file path for additional address' do
      data = {
        'additional_address' => {
          'street' => '123 Fake St.',
          'city' => 'Fakesville',
          'state' => 'FS',
          'postal_code' => '12345',
          'country' => 'USA'
        }
      }
      filler = double('SimpleFormsApi::PdfFiller', generate: 'filled.pdf')
      allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(filler)
      expect(described_class.new(data).send(:get_attachments)).to include('filled.pdf')
    end

    it 'returns attachments for supporting documents' do
      data = {
        'veteran_supporting_documents' => [
          { 'confirmation_code' => 'abc' }
        ]
      }
      attachment = double('PersistentAttachment', to_pdf: 'pdf_path')
      allow(PersistentAttachment).to receive(:where).with(guid: ['abc']).and_return([attachment])
      expect(described_class.new(data).send(:get_attachments)).to include('pdf_path')
    end

    it 'returns empty array if no attachments' do
      expect(described_class.new({}).send(:get_attachments)).to eq []
    end
  end

  describe 'private #fill_pdf_with_additional_address' do
    it 'calls PdfFiller with correct params and returns generated file path' do
      data = {
        'additional_address' => {
          'street' => '123 Fake St.',
          'city' => 'Fakesville',
          'state' => 'FS',
          'postal_code' => '12345',
          'country' => 'USA'
        },
        'additional_copies' => 2
      }
      filler = double('SimpleFormsApi::PdfFiller', generate: 'filled.pdf')
      allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(filler)
      expect(described_class.new(data).send(:fill_pdf_with_additional_address)).to eq 'filled.pdf'
    end
  end
end
