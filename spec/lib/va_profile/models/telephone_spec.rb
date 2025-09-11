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

    context 'with an international country code' do
      it 'returns nil' do
        telephone.is_international = true
        telephone.country_code = '44'
        expect(telephone.formatted_phone).to be_nil
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

    it 'area_code must be present when is_international is false' do
      telephone = build(:telephone, area_code: nil, is_international: false)
      expect(telephone).not_to be_valid
      expect(telephone.errors[:area_code].first).to eq("can't be blank")
    end

    context 'is_international' do
      it 'is valid when set to false' do
        phone = build(:telephone, is_international: false)
        expect(phone).to be_valid
      end

      it 'is valid when set to true' do
        phone = build(:telephone, is_international: true)
        expect(phone).to be_valid
      end

      # This is not possible because there's a default
      # it 'is not valid when nil' do
      #   phone = build(:telephone, is_international: nil)
      #   expect(phone).not_to be_valid
      # end
    end

    context 'country_code' do
      it 'is valid when set to a 1- to 3-digit number or numeric string', :aggregate_failures do
        valid_country_codes = ['1', 1, '44', 964]

        valid_country_codes.each do |valid_country_code|
          phone = build(:telephone, country_code: valid_country_code)
          expect(phone).to be_valid
        end
      end

      it 'is not valid when includes non-numeric characters', :aggregate_failures do
        invalid_country_codes = %w[abc ## +123]

        invalid_country_codes.each do |invalid_country_code|
          phone = build(:telephone, country_code: invalid_country_code)
          expect(phone).not_to be_valid
        end
      end

      it 'is not valid when starts with 0 or is longer than 3 digits', :aggregate_failures do
        invalid_country_codes = %w[01 9641 55555]

        invalid_country_codes.each do |invalid_country_code|
          phone = build(:telephone, country_code: invalid_country_code)
          expect(phone).not_to be_valid
        end
      end

      # This is not possible because there's a default value
      # it 'is not valid when nil' do
      #   phone = build(:telephone, country_code: nil)
      #   expect(phone).not_to be_valid
      # end
    end
  end

  describe '.build_from' do
    it 'builds a Telephone from a hash' do
      body = {
        'area_code' => '303',
        'country_code' => '1',
        'create_date' => '2020-01-01T00:00:00Z',
        'phone_number_ext' => '123',
        'telephone_id' => 42,
        'international_indicator' => false,
        'text_message_capable_ind' => true,
        'text_message_perm_ind' => true,
        'voice_mail_acceptable_ind' => true,
        'phone_number' => '5551234',
        'phone_type' => 'MOBILE',
        'source_date' => '2020-01-01T00:00:00Z',
        'tx_audit_id' => 'abc123',
        'tty_ind' => false,
        'update_date' => '2020-01-02T00:00:00Z',
        'vet360_id' => 'v360id',
        'va_profile_id' => 'vaproid',
        'effective_end_date' => '2020-12-31T00:00:00Z',
        'effective_start_date' => '2020-01-01T00:00:00Z'
      }
      telephone = described_class.build_from(body)
      expect(telephone).to be_a(described_class)
      expect(telephone.area_code).to be('303')
      expect(telephone.phone_type).to be('MOBILE')
      expect(telephone.is_international).to be(false)
    end
  end

  describe '#in_json' do
    it 'returns a JSON string with expected keys' do
      telephone = build(:telephone)
      json = JSON.parse(telephone.in_json)
      expect(json).to have_key('bio')
      expect(json['bio']).to have_key('areaCode')
      expect(json['bio']).to have_key('countryCode')
      expect(json['bio']).to have_key('phoneNumber')
      expect(json['bio']).to have_key('phoneType')
    end
  end
end
