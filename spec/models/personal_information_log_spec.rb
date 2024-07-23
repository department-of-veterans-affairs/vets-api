# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PersonalInformationLog, type: :model do
  let(:personal_information_log) { build(:personal_information_log) }

  describe 'validations' do
    context 'when all attributes are valid' do
      it 'is valid' do
        expect(personal_information_log).to be_valid
      end
    end

    context 'when error class is missing' do
      it 'is invalid' do
        personal_information_log.error_class = nil
        expect(personal_information_log).not_to be_valid
        expect(personal_information_log.errors.attribute_names).to include(:error_class)
        expect(personal_information_log.errors.full_messages).to include("Error class can't be blank")
      end
    end
  end

  describe '#data' do
    context 'when data is missing' do
      let(:pi_log) { build(:personal_information_log, data: nil) }

      it 'does not raise error' do
        expect { pi_log.save }.not_to raise_error
      end
    end

    context 'when all attributes are present' do
      it 'simply returns data' do
        expect(personal_information_log.data).to eq({ 'foo' => 1 })
      end

      it 'populates the data_ciphertext' do
        expect(personal_information_log.data_ciphertext).to be_present
      end
    end
  end
end
