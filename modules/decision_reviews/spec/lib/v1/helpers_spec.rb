# frozen_string_literal: true

require 'rails_helper'
require 'decision_reviews/v1/helpers'

describe DecisionReviews::V1::Helpers do
  let(:helper) { Class.new { include DecisionReviews::V1::Helpers }.new }

  describe 'format_phone_number' do
    context 'international phone numbers' do
      it 'returns {} if phone is nil' do
        expect(helper.format_phone_number(nil)).to eq({})
      end

      it 'formats phone number with country code, area code, and number' do
        phone = { 'countryCode' => '44', 'areaCode' => '20', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          internationalPhoneNumber: '+44 205550456'
                                                        })
      end

      it 'formats phone number with nil area code' do
        phone = { 'areaCode' => nil, 'countryCode' => '44', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          internationalPhoneNumber: '+44 5550456'
                                                        })
      end

      it 'formats phone number with empty area code' do
        phone = { 'areaCode' => '', 'countryCode' => '44', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          internationalPhoneNumber: '+44 5550456'
                                                        })
      end

      it 'formats phone number with no area code' do
        phone = { 'countryCode' => '44', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          internationalPhoneNumber: '+44 5550456'
                                                        })
      end
    end

    context 'domestic phone numbers' do
      it 'formats phone number with nil country code' do
        phone = { 'countryCode' => nil, 'areaCode' => '210', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          veteranPhone: '2105550456'
                                                        })
      end

      it 'formats phone number with empty country code' do
        phone = { 'countryCode' => '', 'areaCode' => '210', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          veteranPhone: '2105550456'
                                                        })
      end

      it 'formats phone number with no country code' do
        phone = { 'areaCode' => '210', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          veteranPhone: '2105550456'
                                                        })
      end
    end
  end
end
