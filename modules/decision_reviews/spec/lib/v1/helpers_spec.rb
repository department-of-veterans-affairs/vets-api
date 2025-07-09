# frozen_string_literal: true

require 'rails_helper'
require 'decision_reviews/v1/helpers'

describe DecisionReviews::V1::Helpers do
  let(:helper) { Class.new { include DecisionReviews::V1::Helpers }.new }

  describe 'format_phone_number' do
    it 'returns nil if phone is nil' do
      expect(helper.format_phone_number(nil)).to be_nil
    end

    it 'formats phone number with country code, area code, and number' do
      phone = { 'countryCode' => '44', 'areaCode' => '20', 'phoneNumber' => '5550456' }
      expect(helper.format_phone_number(phone)).to eq({
                                                        number: '205550456',
                                                        countryCode: '44'
                                                      })
    end

    it 'handles nil area code by using an empty string' do
      phone = { 'areaCode' => nil, 'countryCode' => '44', 'phoneNumber' => '5550456' }
      expect(helper.format_phone_number(phone)).to eq({
                                                        number: '5550456',
                                                        countryCode: '44'
                                                      })
    end

    it 'handles missing area code by using an empty string' do
      phone = { 'countryCode' => '44', 'phoneNumber' => '5550456' }
      expect(helper.format_phone_number(phone)).to eq({
                                                        number: '5550456',
                                                        countryCode: '44'
                                                      })
    end

    it 'handles missing country code by using an empty string' do
      phone = { 'areaCode' => '210', 'phoneNumber' => '5550456' }
      expect(helper.format_phone_number(phone)).to eq({
                                                        number: '2105550456',
                                                        countryCode: ''
                                                      })
    end
  end
end
