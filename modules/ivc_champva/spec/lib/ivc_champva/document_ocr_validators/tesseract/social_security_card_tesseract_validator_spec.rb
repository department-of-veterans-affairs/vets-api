# frozen_string_literal: true

require 'rails_helper'
require 'ivc_champva/document_ocr_validators/tesseract/social_security_card_tesseract_validator'

RSpec.describe IvcChampva::DocumentOcrValidators::Tesseract::SocialSecurityCardTesseractValidator do
  let(:validator) { described_class.new }

  describe '#suitable_for_document?' do
    it 'returns true for text containing SSN keywords' do
      text = 'SOCIAL SECURITY ADMINISTRATION This number has been established for JOHN DOE'
      expect(validator.suitable_for_document?(text)).to be true
    end

    it 'returns true for text containing "social security number"' do
      text = 'Please provide your social security number for verification'
      expect(validator.suitable_for_document?(text)).to be true
    end

    it 'returns true for text containing "ssn"' do
      text = 'SSN: 123-45-6789'
      expect(validator.suitable_for_document?(text)).to be true
    end

    it 'returns false for unrelated text' do
      text = 'This is just regular text without the keywords'
      expect(validator.suitable_for_document?(text)).to be false
    end
  end

  describe '#extract_fields' do
    it 'extracts SSN and name from typical SSN card text' do
      text = 'SOCIAL SECURITY This number has been established for JOHN DOE 123-45-6789'
      result = validator.extract_fields(text)

      expect(result[:ssn]).to eq('123-45-6789')
      expect(result[:name]).to eq('JOHN DOE')
    end

    it 'extracts SSN without dashes' do
      text = 'NAME JOHN SMITH social security 123456789'
      result = validator.extract_fields(text)

      expect(result[:ssn]).to eq('123-45-6789')
      expect(result[:name]).to eq('JOHN SMITH')
    end

    it 'extracts SSN with spaces' do
      text = 'MARY JOHNSON 123 45 6789'
      result = validator.extract_fields(text)

      expect(result[:ssn]).to eq('123-45-6789')
      expect(result[:name]).to eq('MARY JOHNSON')
    end

    it 'handles case where name is after "NAME:" label' do
      text = 'social security NAME: ALICE WILLIAMS 987-65-4321'
      result = validator.extract_fields(text)

      expect(result[:name]).to eq('ALICE WILLIAMS')
      expect(result[:ssn]).to eq('987-65-4321')
    end

    it 'returns nil values when fields not found' do
      text = 'This document contains no relevant information'
      result = validator.extract_fields(text)

      expect(result[:ssn]).to be_nil
      expect(result[:name]).to be_nil
    end
  end

  describe '#valid_document?' do
    context 'when document is suitable and has required fields' do
      it 'returns true' do
        text = 'SOCIAL SECURITY This number has been established for JOHN DOE 123-45-6789'
        expect(validator.valid_document?(text)).to be true
      end
    end

    context 'when document is suitable but missing SSN' do
      it 'returns false' do
        text = 'SOCIAL SECURITY This number has been established for JOHN DOE'
        expect(validator.valid_document?(text)).to be false
      end
    end

    context 'when document is suitable but missing name' do
      it 'returns false' do
        text = 'SOCIAL SECURITY 123-45-6789 no name here'
        expect(validator.valid_document?(text)).to be false
      end
    end

    context 'when document is not suitable' do
      it 'returns false' do
        text = 'This is a medical prescription for John Doe'
        expect(validator.valid_document?(text)).to be false
      end
    end
  end

  describe '#confidence_score' do
    it 'returns 0.0 for unsuitable documents' do
      text = 'This is not a related document'
      expect(validator.confidence_score(text)).to eq(0.0)
    end

    it 'returns base score for SSN keywords only' do
      text = 'SOCIAL SECURITY ADMINISTRATION'
      score = validator.confidence_score(text)
      expect(score).to eq(0.3)
    end

    it 'adds bonus for extracted SSN' do
      text = 'social security number 123-45-6789 no name'
      score = validator.confidence_score(text)
      expect(score).to eq(0.7) # 0.3 base + 0.4 SSN bonus
    end

    it 'adds bonus for extracted name' do
      text = 'SOCIAL SECURITY NAME: JOHN DOE'
      score = validator.confidence_score(text)
      expect(score).to eq(0.6) # 0.3 base + 0.3 name bonus
    end

    it 'returns maximum score for both SSN and name' do
      text = 'SOCIAL SECURITY NAME: JOHN DOE 123-45-6789'
      score = validator.confidence_score(text)
      expect(score).to eq(1.0) # 0.3 base + 0.4 SSN + 0.3 name
    end
  end

  describe '#document_type' do
    it 'returns the correct document type' do
      expect(validator.document_type).to eq('social_security_card')
    end
  end

  describe 'private methods' do
    describe '#normalize_ssn' do
      it 'formats clean 9-digit number' do
        result = validator.send(:normalize_ssn, '123456789')
        expect(result).to eq('123-45-6789')
      end

      it 'cleans and formats number with dashes' do
        result = validator.send(:normalize_ssn, '123-45-6789')
        expect(result).to eq('123-45-6789')
      end

      it 'cleans and formats number with spaces' do
        result = validator.send(:normalize_ssn, '123 45 6789')
        expect(result).to eq('123-45-6789')
      end

      it 'returns nil for invalid length' do
        result = validator.send(:normalize_ssn, '12345678')
        expect(result).to be_nil
      end
    end

    describe '#valid_name?' do
      it 'accepts valid names' do
        expect(validator.send(:valid_name?, 'John Doe')).to be true
        expect(validator.send(:valid_name?, 'Mary Jane Smith')).to be true
      end

      it 'rejects names that are too short' do
        expect(validator.send(:valid_name?, 'Jo')).to be false
      end

      it 'rejects names that are too long' do
        long_name = 'A' * 51
        expect(validator.send(:valid_name?, long_name)).to be false
      end

      it 'rejects names with invalid characters' do
        expect(validator.send(:valid_name?, 'John123')).to be false
        expect(validator.send(:valid_name?, 'John@Doe')).to be false
      end

      it 'accepts names with standard characters and spaces' do
        expect(validator.send(:valid_name?, 'John O Doe')).to be true
      end
    end
  end
end
