# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/telephone'

describe VAProfile::Models::Telephone do
  describe '#formatted_phone' do
    let(:telephone) { build(:telephone) }

    context 'with no phone number' do
      it 'returns nil' do
        telephone.phone_number = nil
        expect(telephone.formatted_phone).to be_nil
      end
    end

    context 'with no extension' do
      it 'returns the formatted phone number' do
        expect(telephone.formatted_phone).to eq('(303) 555-1234')
      end
    end

    context 'with an extension' do
      it 'returns number with extension' do
        telephone.extension = '123'
        expect(telephone.formatted_phone).to eq('(303) 555-1234 Ext. 123')
      end
    end
  end

  describe 'validations' do
    it 'we have a valid factory in place' do
      expect(build(:telephone)).to be_valid
    end

    it 'extension must be less than or equal to 6 digits' do
      telephone = build(:telephone)
      telephone.extension = '1234567'
      expect(telephone).not_to be_valid
      expect(telephone.errors[:extension].first).to eq('is too long (maximum is 6 characters)')
    end

    it 'extension must be numeric' do
      telephone = build(:telephone)
      telephone.extension = 'ABCDEF'
      expect(telephone).not_to be_valid
      expect(telephone.errors[:extension].first).to eq('is not a number')
    end

    context 'is_international' do
      it 'is valid when set to false' do
        phone = build(:telephone, is_international: false)

        expect(phone).to be_valid
      end

      it 'is not valid when set to true' do
        phone = build(:telephone, is_international: true)

        expect(phone).not_to be_valid
      end

      it 'is not valid when nil' do
        phone = build(:telephone, is_international: nil)

        expect(phone).not_to be_valid
      end
    end

    context 'country_code' do
      it 'is valid when set to "1" or 1', :aggregate_failures do
        valid_country_codes = ['1', 1]

        valid_country_codes.each do |valid_country_code|
          phone = build(:telephone, country_code: valid_country_code)

          expect(phone).to be_valid
        end
      end

      it 'is not valid when set to anything other than "1"', :aggregate_failures do
        invalid_country_codes = %w[2 15 abc 01]

        invalid_country_codes.each do |invalid_country_code|
          phone = build(:telephone, country_code: invalid_country_code)

          expect(phone).not_to be_valid
        end
      end

      it 'is not valid when nil' do
        phone = build(:telephone, country_code: nil)

        expect(phone).not_to be_valid
      end
    end
  end
end
