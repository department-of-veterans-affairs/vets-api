# frozen_string_literal: true

require 'rails_helper'
require 'pdf_utilities/pdf_validator'

describe PDFUtilities::PDFValidator::ValidationResult do
  let(:validation_result) { described_class.new }
  let(:first_error) { 'an error' }
  let(:second_error) { 'another error' }

  describe '#initialize' do
    subject { validation_result }

    it 'sets the errors instance variable to an empty array' do
      expect(subject.errors).to eql([])
    end
  end

  describe '#add_error' do
    before { validation_result.add_error(first_error) }

    it 'appends the error string to the errors array' do
      expect(validation_result.errors).to eql([first_error])

      validation_result.add_error(second_error)
      expect(validation_result.errors).to eql([first_error, second_error])
    end
  end

  describe '#valid_pdf?' do
    context 'when there are no errors' do
      it 'returns true' do
        expect(validation_result.valid_pdf?).to be(true)
      end
    end

    context 'when there is one error' do
      before { validation_result.add_error(first_error) }

      it 'returns false' do
        expect(validation_result.valid_pdf?).to be(false)
      end
    end

    context 'when there is more than one error' do
      before do
        validation_result.add_error(first_error)
        validation_result.add_error(second_error)
      end

      it 'returns false' do
        expect(validation_result.valid_pdf?).to be(false)
      end
    end
  end
end
