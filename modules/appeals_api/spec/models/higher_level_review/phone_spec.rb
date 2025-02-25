# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HigherLevelReview::Phone do
  def phone(country, area, number, ext)
    described_class.new(
      countryCode: country,
      areaCode: area,
      phoneNumber: number,
      phoneNumberExt: ext
    )
  end

  def phone_with_ext(ext)
    phone('6', '888', '5554444', ext)
  end

  describe 'to_s' do
    it 'does not print the country code for a US number' do
      expect(phone('1', '888', '5554444', '9').to_s).to eq '888-555-4444 ext 9'
    end

    it 'assumes US when no country code given' do
      expect(phone(nil, '888', '5554444', '9').to_s).to eq '888-555-4444 ext 9'
    end

    it 'preserves leading 0s' do
      expect(phone(nil, '022', '0120123', '0').to_s).to eq '022-012-0123 ext 0'
    end

    it 'shrinks extension to stay within 20 characters (notice missing space)' do
      phone = phone_with_ext('9')
      expect(phone.to_s).to eq '+6-888-555-4444 ext9'
      expect(phone.too_long?).to be false
    end

    it 'shrinks extension more' do
      phone = phone_with_ext('99')
      expect(phone.to_s).to eq '+6-888-555-4444 ex99'
      expect(phone.too_long?).to be false
    end

    it 'keeps on shrinking extension' do
      phone = phone_with_ext('999')
      expect(phone.to_s).to eq '+6-888-555-4444 x999'
      expect(phone.too_long?).to be false
    end

    it 'maximum extension shrinkage' do
      phone = phone_with_ext('9999')
      expect(phone.to_s).to eq '+6-888-555-4444x9999'
      expect(phone.too_long?).to be false
    end

    it 'no longer within char limit' do
      phone = phone_with_ext('99999')
      expect(phone.to_s).to eq '+6-888-555-4444x99999'
      expect(phone.too_long?).to be true
    end

    it 'is not too long' do
      p = phone('1', '888', '5554444', '9999999')
      expect(p.to_s).to eq '888-555-4444x9999999'
      expect(p.too_long?).to be false
    end

    it 'is too long' do
      p = phone(nil, '888', '5554444', '99999999')
      expect(p.to_s).to eq '888-555-4444x99999999'
      expect(p.too_long?).to be true
    end

    it 'uses less formatting when phone number (areaCode + phoneNumber) is more than ten digits' do
      p = phone(nil, '888', '33333333', nil)
      expect(p.to_s).to eq '88833333333'
      expect(p.too_long?).to be false
    end

    it 'uses less formatting when phone number is less than ten digits' do
      p = phone('99', '02', '3333', 'ZeBrA2')
      expect(p.to_s).to eq '+99-023333 extZeBrA2'
      expect(p.too_long?).to be false
    end

    it 'returns empty string when fields are blank' do
      expect(phone(nil, '', '    ', nil).to_s).to eq ''
    end

    it 'returns empty string when initialized with nil' do
      expect(described_class.new(nil).to_s).to eq ''
    end

    it 'returns empty string when initialized with {}' do
      expect(described_class.new({}).to_s).to eq ''
    end
  end

  describe '#too_long?' do
    it 'is too long' do
      expect(phone('1', '888', '5554444', '999999999').too_long?).to be true
    end

    it 'is not too long' do
      expect(phone(nil, '888', '5554444', nil).too_long?).to be false
    end
  end

  describe '#too_long_error_message' do
    it 'has error message when phone number is too long' do
      expect(phone('1', '888', '5554444', '999999999').too_long_error_message).to be_a String
    end

    it 'has no error message when phone number is not too long' do
      expect(phone(nil, '888', '5554444', nil).too_long_error_message).to be_nil
    end
  end
end
