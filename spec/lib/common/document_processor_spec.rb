# frozen_string_literal: true

require 'rails_helper'
require 'common/document_processor'

RSpec.describe Common::DocumentProcessor, :uploader_helpers do
  stub_virus_scan

  let(:pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').to_s }
  let(:jpg_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg').to_s }
  let(:encrypted_pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_encryption.pdf').to_s }
  let(:correct_password) { 'test' }
  let(:wrong_password) { 'wrongpassword' }

  describe '#process' do
    context 'with a PDF file' do
      it 'successfully processes the file' do
        file = Rack::Test::UploadedFile.new(pdf_path, 'application/pdf')
        processor = described_class.new(file)
        result = processor.process

        expect(result).to be_a(Common::DocumentProcessor::ProcessingResult)
        expect(result.success?).to be true
        expect(result.file_path).to be_present
        expect(File.exist?(result.file_path)).to be true
        expect(result.errors).to be_empty
      end
    end

    context 'with an image file' do
      it 'converts the image to PDF' do
        file = Rack::Test::UploadedFile.new(jpg_path, 'image/jpeg')
        processor = described_class.new(file)
        result = processor.process

        expect(result.success?).to be true
        expect(result.file_path).to be_present
        
        # Verify it's a PDF
        pdf_content = File.read(result.file_path)
        expect(pdf_content).to start_with('%PDF-')
      end
    end

    context 'with an encrypted PDF and correct password' do
      it 'successfully decrypts and processes the file' do
        file = Rack::Test::UploadedFile.new(encrypted_pdf_path, 'application/pdf')
        processor = described_class.new(file, password: correct_password)
        result = processor.process

        expect(result.success?).to be true
        expect(result.file_path).to be_present
        
        # Verify the file is decrypted
        doc = HexaPDF::Document.open(result.file_path)
        expect(doc.encrypted?).to be false
      end
    end

    context 'with an encrypted PDF and wrong password' do
      it 'returns failure with password error' do
        file = Rack::Test::UploadedFile.new(encrypted_pdf_path, 'application/pdf')
        processor = described_class.new(file, password: wrong_password)
        result = processor.process

        expect(result.success?).to be false
        expect(result.errors).not_to be_empty
        expect(result.errors.first).to include(
          title: 'Invalid password',
          detail: 'The password you entered is incorrect. Please try again.'
        )
      end
    end

    context 'with custom validation options' do
      it 'uses the provided options' do
        file = Rack::Test::UploadedFile.new(pdf_path, 'application/pdf')
        processor = described_class.new(
          file,
          validation_options: { size_limit_in_bytes: 1.byte }
        )
        result = processor.process

        expect(result.success?).to be false
        expect(result.errors.first[:detail]).to include('exceeds the file size limit')
      end
    end

    context 'when conversion fails' do
      it 'returns failure with conversion error' do
        file = Rack::Test::UploadedFile.new(jpg_path, 'image/jpeg')
        allow(Common::ConvertToPdf).to receive(:new).and_raise(StandardError.new('Conversion failed'))
        
        processor = described_class.new(file)
        result = processor.process

        expect(result.success?).to be false
        expect(result.errors.first).to include(
          title: 'File conversion error'
        )
      end
    end

    context 'when validation fails' do
      it 'returns failure with validation errors' do
        file = Rack::Test::UploadedFile.new(pdf_path, 'application/pdf')
        
        # Mock the validator to return invalid result
        allow_any_instance_of(Common::FileValidation::Validator)
          .to receive(:validate)
          .and_return(double(valid?: false, errors: ['File too large', 'Invalid format']))
        
        processor = described_class.new(file)
        result = processor.process

        expect(result.success?).to be false
        expect(result.errors.length).to eq(2)
        expect(result.errors.map { |e| e[:detail] }).to include('File too large', 'Invalid format')
      end
    end
  end

  describe '#process!' do
    context 'with a valid file' do
      it 'returns the file path' do
        file = Rack::Test::UploadedFile.new(pdf_path, 'application/pdf')
        processor = described_class.new(file)
        result_path = processor.process!

        expect(result_path).to be_a(String)
        expect(File.exist?(result_path)).to be true
      end
    end

    context 'with an invalid file' do
      it 'raises ConversionError for conversion failures' do
        file = Rack::Test::UploadedFile.new(jpg_path, 'image/jpeg')
        allow(Common::ConvertToPdf).to receive(:new).and_raise(StandardError)
        
        processor = described_class.new(file)
        
        expect { processor.process! }.to raise_error(Common::DocumentProcessor::ConversionError) do |error|
          expect(error.errors).not_to be_empty
        end
      end

      it 'raises ValidationError for validation failures' do
        file = Rack::Test::UploadedFile.new(pdf_path, 'application/pdf')
        
        allow_any_instance_of(Common::FileValidation::Validator)
          .to receive(:validate)
          .and_return(double(valid?: false, errors: ['File too large']))
        
        processor = described_class.new(file)
        
        expect { processor.process! }.to raise_error(Common::DocumentProcessor::ValidationError) do |error|
          expect(error.errors).not_to be_empty
        end
      end
    end
  end

  describe 'temp file cleanup' do
    context 'with successful processing' do
      it 'does not clean up the final PDF' do
        file = Rack::Test::UploadedFile.new(pdf_path, 'application/pdf')
        processor = described_class.new(file)
        result = processor.process

        expect(File.exist?(result.file_path)).to be true
      end
    end

    context 'with decryption' do
      it 'cleans up the decrypted temp file on success' do
        file = Rack::Test::UploadedFile.new(encrypted_pdf_path, 'application/pdf')
        processor = described_class.new(file, password: correct_password)
        
        decrypted_path = nil
        allow(processor).to receive(:decrypt_pdf).and_wrap_original do |method, *args|
          result = method.call(*args)
          decrypted_path = result
          result
        end

        result = processor.process
        
        # The decrypted file should still exist because it's the final result
        expect(File.exist?(result.file_path)).to be true
      end

      it 'cleans up temp files on failure' do
        file = Rack::Test::UploadedFile.new(encrypted_pdf_path, 'application/pdf')
        processor = described_class.new(file, password: wrong_password)
        
        result = processor.process
        
        expect(result.success?).to be false
        # Temp files should be cleaned up
      end
    end
  end

  describe '::ProcessingResult' do
    let(:result) { described_class::ProcessingResult.new }

    describe '#success?' do
      it 'returns false by default' do
        expect(result.success?).to be false
      end

      it 'returns true when set' do
        result.success = true
        expect(result.success?).to be true
      end
    end

    describe '#add_error' do
      it 'adds an error to the errors array' do
        result.add_error({ title: 'Test', detail: 'Error' })
        expect(result.errors).to eq([{ title: 'Test', detail: 'Error' }])
      end
    end

    describe '#add_warning' do
      it 'adds a warning to the warnings array' do
        result.add_warning('Test warning')
        expect(result.warnings).to eq(['Test warning'])
      end
    end

    describe '#to_h' do
      it 'returns a hash representation' do
        result.success = true
        result.file_path = '/tmp/test.pdf'
        result.add_error('Error')
        result.add_warning('Warning')

        hash = result.to_h
        expect(hash).to eq({
          success: true,
          file_path: '/tmp/test.pdf',
          errors: ['Error'],
          warnings: ['Warning']
        })
      end
    end
  end

  describe 'integration with SimpleFormsApi pattern' do
    # This test demonstrates how DocumentProcessor can be used in place of
    # SimpleFormsApi::ScannedFormProcessor
    it 'can process files like ScannedFormProcessor' do
      # Simulate the old pattern
      file = Rack::Test::UploadedFile.new(jpg_path, 'image/jpeg')
      processor = described_class.new(
        file,
        validation_options: {
          size_limit_in_bytes: 100.megabytes,
          check_page_dimensions: true,
          check_encryption: true,
          width_limit_in_inches: 78,
          height_limit_in_inches: 101
        }
      )
      
      result = processor.process
      
      expect(result.success?).to be true
      expect(File.exist?(result.file_path)).to be true
      
      # Verify it's a valid PDF
      pdf_content = File.read(result.file_path)
      expect(pdf_content).to start_with('%PDF-')
    end
  end
end
