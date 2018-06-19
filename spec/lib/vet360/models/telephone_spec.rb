# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Models::Telephone do
  describe 'validations' do
    it 'we have a valid factory in place' do
      expect(build(:telephone)).to be_valid
    end

    context 'is_international' do
      it 'is valid when set to false' do
        phone = build(:telephone, is_international: false)

        expect(phone).to be_valid
      end

      it 'is not valid when set to true' do
        phone = build(:telephone, is_international: true)

        expect(phone).to_not be_valid
      end

      it 'is not valid when nil' do
        phone = build(:telephone, is_international: nil)

        expect(phone).to_not be_valid
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

          expect(phone).to_not be_valid
        end
      end

      it 'is not valid when nil' do
        phone = build(:telephone, country_code: nil)

        expect(phone).to_not be_valid
      end
    end
  end
end
