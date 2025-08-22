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

  describe '#normalize_area_code_for_lighthouse_schema' do
    context 'when area_code is present and valid with 3 characters (domestic number)' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => '123',
                  'phoneNumber' => '1234567',
                  'countryCode' => '1'
                }
              }
            }
          }
        }
      end

      it 'returns the original object unchanged' do
        expected_result = req_body_obj
        expect(helper.normalize_area_code_for_lighthouse_schema(req_body_obj)).to eq(expected_result)
      end
    end

    context 'when area_code is present and valid with 2 characters (international number)' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => '10',
                  'phoneNumber' => '49808232',
                  'countryCode' => '100'
                }
              }
            }
          }
        }
      end

      it 'returns the original object unchanged' do
        expected_result = req_body_obj
        expect(helper.normalize_area_code_for_lighthouse_schema(req_body_obj)).to eq(expected_result)
      end
    end

    context 'when area_code is present and empty' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => '',
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      let(:expected_result) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      it 'returns the object without an areaCode' do
        expect(helper.normalize_area_code_for_lighthouse_schema(req_body_obj)).to eq(expected_result)
      end
    end

    context 'when area_code is present and nil' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => nil,
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      let(:expected_result) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      it 'returns the object without an areaCode' do
        expect(helper.normalize_area_code_for_lighthouse_schema(req_body_obj)).to eq(expected_result)
      end
    end
  end
end
