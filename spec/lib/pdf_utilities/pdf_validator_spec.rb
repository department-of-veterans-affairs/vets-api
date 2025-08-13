# frozen_string_literal: true

require 'rails_helper'
require 'pdf_utilities/pdf_validator'

RSpec.describe PDFUtilities::PDFValidator do
  describe PDFUtilities do
    describe '.formatted_file_size' do
      it 'formats bytes correctly' do
        expect(PDFUtilities.formatted_file_size(500)).to eq('500 bytes')
        expect(PDFUtilities.formatted_file_size(999)).to eq('999 bytes')
      end

      it 'formats kilobytes correctly' do
        expect(PDFUtilities.formatted_file_size(1.kilobyte)).to eq('1 KB')
        expect(PDFUtilities.formatted_file_size(2.5.kilobytes)).to eq('2.5 KB')
        expect(PDFUtilities.formatted_file_size(1023.kilobytes)).to eq('1023 KB')
      end

      it 'formats megabytes correctly' do
        expect(PDFUtilities.formatted_file_size(1.megabyte)).to eq('1 MB')
        expect(PDFUtilities.formatted_file_size(2.5.megabytes)).to eq('2.5 MB')
        expect(PDFUtilities.formatted_file_size(1023.megabytes)).to eq('1023 MB')
      end

      it 'formats gigabytes correctly' do
        expect(PDFUtilities.formatted_file_size(1.gigabyte)).to eq('1 GB')
        expect(PDFUtilities.formatted_file_size(2.5.gigabytes)).to eq('2.5 GB')
        expect(PDFUtilities.formatted_file_size(10.gigabytes)).to eq('10 GB')
      end

      it 'removes trailing zeros in formatted output' do
        expect(PDFUtilities.formatted_file_size(1.0.megabyte)).to eq('1 MB')
        expect(PDFUtilities.formatted_file_size(2.0.kilobytes)).to eq('2 KB')
      end
    end
  end

  describe PDFUtilities::PDFValidator::ValidationResult do
    subject(:result) { described_class.new }

    describe '#initialize' do
      it 'initializes with empty errors array' do
        expect(result.errors).to eq([])
      end
    end

    describe '#add_error' do
      it 'adds error message to errors array' do
        result.add_error('Test error')
        expect(result.errors).to include('Test error')
      end

      it 'allows multiple errors' do
        result.add_error('Error 1')
        result.add_error('Error 2')
        expect(result.errors).to eq(['Error 1', 'Error 2'])
      end
    end

    describe '#valid_pdf?' do
      it 'returns true when no errors present' do
        expect(result.valid_pdf?).to be true
      end

      it 'returns false when errors are present' do
        result.add_error('Test error')
        expect(result.valid_pdf?).to be false
      end
    end
  end

  describe PDFUtilities::PDFValidator::Validator do
    let(:file_path) { 'tmp/test_file.pdf' }
    let(:mock_metadata) { double('pdf_metadata') }

    before do
      # Create a test file
      File.write(file_path, 'test pdf content')
    end

    after do
      File.delete(file_path) if File.exist?(file_path)
    end

    describe '#initialize' do
      it 'sets default options' do
        validator = described_class.new(file_path)
        expect(validator.instance_variable_get(:@options)[:size_limit_in_bytes]).to eq(100.megabytes)
        expect(validator.instance_variable_get(:@options)[:check_page_dimensions]).to be true
        expect(validator.instance_variable_get(:@options)[:check_encryption]).to be true
        expect(validator.instance_variable_get(:@options)[:width_limit_in_inches]).to eq(21)
        expect(validator.instance_variable_get(:@options)[:height_limit_in_inches]).to eq(21)
      end

      it 'merges custom options with defaults' do
        custom_options = { size_limit_in_bytes: 50.megabytes, check_encryption: false }
        validator = described_class.new(file_path, custom_options)
        options = validator.instance_variable_get(:@options)
        
        expect(options[:size_limit_in_bytes]).to eq(50.megabytes)
        expect(options[:check_encryption]).to be false
        expect(options[:check_page_dimensions]).to be true # default preserved
      end
    end

    describe '#validate' do
      let(:validator) { described_class.new(file_path) }

      before do
        allow(PdfInfo::Metadata).to receive(:read).with(file_path).and_return(mock_metadata)
        allow(mock_metadata).to receive(:encrypted?).and_return(false)
        allow(mock_metadata).to receive(:present?).and_return(true)
        allow(mock_metadata).to receive(:oversized_pages_inches).and_return([])
      end

      it 'returns a ValidationResult' do
        result = validator.validate
        expect(result).to be_a(PDFUtilities::PDFValidator::ValidationResult)
      end

      it 'initializes result and pdf_metadata' do
        validator.validate
        expect(validator.result).to be_a(PDFUtilities::PDFValidator::ValidationResult)
        expect(validator.pdf_metadata).to eq(mock_metadata)
      end

      context 'file size validation' do
        it 'passes validation for files under size limit' do
          result = validator.validate
          expect(result.valid_pdf?).to be true
        end

        it 'fails validation for files over size limit' do
          large_content = 'x' * (101.megabytes)
          File.write(file_path, large_content)
          
          result = validator.validate
          expect(result.valid_pdf?).to be false
          expect(result.errors).to include(
            'Document exceeds the file size limit of 100 MB'
          )
        end

        it 'uses custom size limit when provided' do
          small_limit = 10 # 10 bytes
          validator = described_class.new(file_path, size_limit_in_bytes: small_limit)
          
          result = validator.validate
          expect(result.valid_pdf?).to be false
          expect(result.errors).to include(
            'Document exceeds the file size limit of 10 bytes'
          )
        end
      end

      context 'PDF metadata validation' do
        it 'handles valid PDF metadata' do
          result = validator.validate
          expect(result.valid_pdf?).to be true
        end

        it 'handles incorrect password error' do
          allow(PdfInfo::Metadata).to receive(:read).and_raise(
            PdfInfo::MetadataReadError.new('Incorrect password')
          )
          
          result = validator.validate
          expect(result.valid_pdf?).to be false
          expect(result.errors).to include('Document is locked with a user password')
        end

        it 'handles general metadata read error' do
          allow(PdfInfo::Metadata).to receive(:read).and_raise(
            PdfInfo::MetadataReadError.new('Invalid PDF format')
          )
          
          result = validator.validate
          expect(result.valid_pdf?).to be false
          expect(result.errors).to include('Document is not a valid PDF')
        end
      end

      context 'encryption validation' do
        it 'passes validation for non-encrypted PDFs' do
          allow(mock_metadata).to receive(:encrypted?).and_return(false)
          
          result = validator.validate
          expect(result.valid_pdf?).to be true
        end

        it 'fails validation for encrypted PDFs' do
          allow(mock_metadata).to receive(:encrypted?).and_return(true)
          
          result = validator.validate
          expect(result.valid_pdf?).to be false
          expect(result.errors).to include('Document is encrypted with an owner password')
        end

        it 'skips encryption check when disabled' do
          allow(mock_metadata).to receive(:encrypted?).and_return(true)
          validator = described_class.new(file_path, check_encryption: false)
          
          result = validator.validate
          expect(result.valid_pdf?).to be true
        end

        it 'handles nil metadata gracefully' do
          allow(PdfInfo::Metadata).to receive(:read).and_raise(
            PdfInfo::MetadataReadError.new('Invalid PDF')
          )
          validator = described_class.new(file_path, check_encryption: true)
          
          result = validator.validate
          expect(result.errors).to include('Document is not a valid PDF')
          expect(result.errors).not_to include('Document is encrypted with an owner password')
        end
      end

      context 'page size validation' do
        it 'passes validation for pages within size limits' do
          allow(mock_metadata).to receive(:oversized_pages_inches).with(21, 21).and_return([])
          
          result = validator.validate
          expect(result.valid_pdf?).to be true
        end

        it 'fails validation for oversized pages' do
          allow(mock_metadata).to receive(:oversized_pages_inches).with(21, 21).and_return([1, 3])
          
          result = validator.validate
          expect(result.valid_pdf?).to be false
          expect(result.errors).to include('Document exceeds the page size limit of 21 in. x 21 in.')
        end

        it 'uses custom page size limits' do
          custom_width = 8.5
          custom_height = 11
          validator = described_class.new(file_path, 
            width_limit_in_inches: custom_width,
            height_limit_in_inches: custom_height
          )
          
          allow(mock_metadata).to receive(:oversized_pages_inches).with(custom_width, custom_height).and_return([1])
          
          result = validator.validate
          expect(result.valid_pdf?).to be false
          expect(result.errors).to include('Document exceeds the page size limit of 8.5 in. x 11 in.')
        end

        it 'skips page size check when disabled' do
          allow(mock_metadata).to receive(:oversized_pages_inches).and_return([1, 2, 3])
          validator = described_class.new(file_path, check_page_dimensions: false)
          
          result = validator.validate
          expect(result.valid_pdf?).to be true
        end

        it 'handles nil metadata gracefully' do
          allow(PdfInfo::Metadata).to receive(:read).and_raise(
            PdfInfo::MetadataReadError.new('Invalid PDF')
          )
          validator = described_class.new(file_path, check_page_dimensions: true)
          
          result = validator.validate
          expect(result.errors).to include('Document is not a valid PDF')
          expect(result.errors).not_to include(/page size limit/)
        end
      end

      context 'comprehensive validation scenarios' do
        it 'accumulates multiple errors' do
          large_content = 'x' * (101.megabytes)
          File.write(file_path, large_content)
          
          allow(mock_metadata).to receive(:encrypted?).and_return(true)
          allow(mock_metadata).to receive(:oversized_pages_inches).and_return([1, 2])
          
          result = validator.validate
          expect(result.valid_pdf?).to be false
          expect(result.errors.length).to eq(3)
          expect(result.errors).to include(
            'Document exceeds the file size limit of 100 MB',
            'Document is encrypted with an owner password',
            'Document exceeds the page size limit of 21 in. x 21 in.'
          )
        end

        it 'validates successfully with all checks enabled' do
          # Small file, valid PDF, not encrypted, within page limits
          result = validator.validate
          expect(result.valid_pdf?).to be true
          expect(result.errors).to be_empty
        end
      end
    end

    describe 'constant definitions' do
      it 'defines expected error messages' do
        expect(PDFUtilities::PDFValidator::FILE_SIZE_LIMIT_EXCEEDED_MSG).to eq('Document exceeds the file size limit')
        expect(PDFUtilities::PDFValidator::PAGE_SIZE_LIMIT_EXCEEDED_MSG).to eq('Document exceeds the page size limit')
        expect(PDFUtilities::PDFValidator::USER_PASSWORD_MSG).to eq('Document is locked with a user password')
        expect(PDFUtilities::PDFValidator::OWNER_PASSWORD_MSG).to eq('Document is encrypted with an owner password')
        expect(PDFUtilities::PDFValidator::INVALID_PDF_MSG).to eq('Document is not a valid PDF')
      end
    end
  end
end