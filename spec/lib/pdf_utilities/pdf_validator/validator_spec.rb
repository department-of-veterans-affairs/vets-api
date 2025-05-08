# frozen_string_literal: true

require 'rails_helper'
require 'pdf_utilities/pdf_validator'

describe PDFUtilities::PDFValidator::Validator do
  let(:file) { '/path/to/file' }
  let(:options) { {} }
  let(:validator) { described_class.new(file, options) }

  describe '#initialize' do
    subject { validator }

    it 'sets the file instance variable' do
      expect(subject.instance_variable_get(:@file)).to eql(file)
    end

    context 'when no options are passed' do
      it 'sets the default options' do
        expect(subject.instance_variable_get(:@options)).to eql(described_class::DEFAULT_OPTIONS)
      end
    end

    context 'when some options are passed' do
      let(:options) do
        {
          size_limit_in_bytes: 1.gigabyte,
          width_limit_in_inches: 11,
          height_limit_in_inches: 11,
          check_encryption: false
        }
      end
      let(:expected_result) do
        {
          size_limit_in_bytes: 1.gigabyte,
          check_page_dimensions: true,
          width_limit_in_inches: 11,
          height_limit_in_inches: 11,
          check_encryption: false
        }
      end

      it 'merges the provided and the default options' do
        expect(subject.instance_variable_get(:@options)).to eql(expected_result)
      end
    end
  end

  describe '#validate' do
    subject { validator }

    let(:fixture_path) { Rails.root.join('spec', 'fixtures', 'pdf_utilities', 'pdf_validator') }
    let(:file) { "#{fixture_path}/21x21.pdf" }

    before { validator.validate }

    it 'sets the result' do
      expect(validator.result).to be_a(PDFUtilities::PDFValidator::ValidationResult)
    end

    it 'sets the pdf_metadata' do
      expect(validator.pdf_metadata).to be_a(PdfInfo::Metadata)
    end

    context 'when the file passes all requirements' do
      it 'returns no errors' do
        expect(validator.result.errors).to be_empty
      end
    end

    context 'when the file exceeds the file size limit' do
      let(:options) { { size_limit_in_bytes: 200.kilobytes } }
      let(:file_size_error) { "#{PDFUtilities::PDFValidator::FILE_SIZE_LIMIT_EXCEEDED_MSG} of 200 KB" }

      it 'returns the file size error' do
        expect(validator.result.errors).to eql([file_size_error])
      end
    end

    context 'when the file exceeds the page size limit' do
      let(:page_size_error) { "#{PDFUtilities::PDFValidator::PAGE_SIZE_LIMIT_EXCEEDED_MSG} of 21 in. x 21 in." }

      context 'when the check_page_dimensions option is true' do
        %w[10x102 79x10].each do |file_name|
          let(:file) { "#{fixture_path}/#{file_name}.pdf" }

          it 'returns the page size limit error' do
            expect(validator.result.errors).to eql([page_size_error])
          end
        end
      end

      context 'when the check_page_dimensions option is false' do
        let(:options) { { check_page_dimensions: false } }
        let(:file) { "#{fixture_path}/10x102.pdf" }

        it 'returns no errors' do
          expect(validator.result.errors).to be_empty
        end
      end
    end

    context 'when the file is user password locked' do
      let(:user_password_error) { PDFUtilities::PDFValidator::USER_PASSWORD_MSG }
      let(:file) { "#{fixture_path}/locked.pdf" }

      it 'returns the user password error' do
        expect(validator.result.errors).to eql([user_password_error])
      end
    end

    context 'when the file is owner password encrypted' do
      let(:owner_password_error) { PDFUtilities::PDFValidator::OWNER_PASSWORD_MSG }
      let(:file) { "#{fixture_path}/encrypted.pdf" }

      context 'when the check_encryption option is true' do
        it 'returns the owner password error' do
          expect(validator.result.errors).to eql([owner_password_error])
        end
      end

      context 'when the check_encryption option is false' do
        let(:options) { { check_encryption: false } }

        it 'returns no errors' do
          expect(validator.result.errors).to be_empty
        end
      end
    end

    context 'when the file is not a PDF' do
      let(:invalid_pdf_error) { PDFUtilities::PDFValidator::INVALID_PDF_MSG }
      let(:file) { "#{fixture_path}/metadata.json" }

      it 'returns the invalid PDF error' do
        expect(validator.result.errors).to eql([invalid_pdf_error])
      end
    end

    context 'when the file exceeds the file size limit and is owner password encrypted' do
      let(:options) { { size_limit_in_bytes: 20.kilobytes } }
      let(:file_size_error) { "#{PDFUtilities::PDFValidator::FILE_SIZE_LIMIT_EXCEEDED_MSG} of 20 KB" }
      let(:owner_password_error) { PDFUtilities::PDFValidator::OWNER_PASSWORD_MSG }
      let(:file) { "#{fixture_path}/encrypted.pdf" }

      it 'returns the file size error and the owner password error' do
        expect(validator.result.errors).to eql([file_size_error, owner_password_error])
      end
    end
  end
end
