# frozen_string_literal: true

require 'rails_helper'
require 'common/file_validation'

RSpec.describe Common::FileValidation do
  describe '::Validator' do
    let(:pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').to_s }
    let(:encrypted_pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_encryption.pdf').to_s }

    describe '#validate' do
      context 'with a valid PDF' do
        it 'returns a valid result' do
          validator = described_class::Validator.new(pdf_path)
          result = validator.validate

          expect(result).to be_a(Common::FileValidation::ValidationResult)
          expect(result.valid?).to be true
          expect(result.errors).to be_empty
        end
      end

      context 'with custom options' do
        it 'uses provided size limit' do
          validator = described_class::Validator.new(
            pdf_path,
            size_limit_in_bytes: 1.byte # Very small to force failure
          )
          result = validator.validate

          expect(result.valid?).to be false
          expect(result.errors.first).to include('exceeds the file size limit')
        end

        it 'uses provided page dimension limits' do
          validator = described_class::Validator.new(
            pdf_path,
            width_limit_in_inches: 1,
            height_limit_in_inches: 1
          )
          result = validator.validate

          expect(result.valid?).to be false
          expect(result.errors.first).to include('exceeds the page size limit')
        end
      end

      context 'with an encrypted PDF' do
        it 'detects user password encryption' do
          validator = described_class::Validator.new(
            encrypted_pdf_path,
            check_encryption: true
          )
          result = validator.validate

          expect(result.valid?).to be false
          expect(result.errors).to include('Document is locked with a user password')
        end
      end
    end

    describe '#validate!' do
      context 'with a valid PDF' do
        it 'returns the result without raising' do
          validator = described_class::Validator.new(pdf_path)
          expect { validator.validate! }.not_to raise_error
        end
      end

      context 'with an invalid PDF' do
        it 'raises ValidationError' do
          validator = described_class::Validator.new(
            pdf_path,
            size_limit_in_bytes: 1.byte
          )
          
          expect { validator.validate! }.to raise_error(Common::FileValidation::ValidationError) do |error|
            expect(error.message).to eq('File validation failed')
            expect(error.validation_errors).not_to be_empty
          end
        end
      end
    end
  end

  describe '::ValidationResult' do
    let(:result) { described_class::ValidationResult.new }

    describe '#add_error' do
      it 'adds an error to the errors array' do
        result.add_error('Test error')
        expect(result.errors).to eq(['Test error'])
      end
    end

    describe '#valid?' do
      it 'returns true when there are no errors' do
        expect(result.valid?).to be true
      end

      it 'returns false when there are errors' do
        result.add_error('Test error')
        expect(result.valid?).to be false
      end
    end

    describe '#to_h' do
      it 'returns a hash representation' do
        result.add_error('Test error')
        hash = result.to_h

        expect(hash).to eq({
          valid: false,
          errors: ['Test error']
        })
      end
    end
  end

  describe 'configuration constants' do
    it 'defines STANDARD_PDF_OPTIONS' do
      expect(described_class::STANDARD_PDF_OPTIONS).to be_a(Hash)
      expect(described_class::STANDARD_PDF_OPTIONS[:size_limit_in_bytes]).to eq(100.megabytes)
      expect(described_class::STANDARD_PDF_OPTIONS[:width_limit_in_inches]).to eq(21)
    end

    it 'defines LARGE_PDF_OPTIONS' do
      expect(described_class::LARGE_PDF_OPTIONS).to be_a(Hash)
      expect(described_class::LARGE_PDF_OPTIONS[:size_limit_in_bytes]).to eq(100.megabytes)
      expect(described_class::LARGE_PDF_OPTIONS[:width_limit_in_inches]).to eq(78)
      expect(described_class::LARGE_PDF_OPTIONS[:height_limit_in_inches]).to eq(101)
    end
  end
end
