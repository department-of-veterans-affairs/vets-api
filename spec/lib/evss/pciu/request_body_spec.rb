# frozen_string_literal: true

require 'rails_helper'
require 'evss/pciu/request_body'

describe EVSS::PCIU::RequestBody do
  let(:phone) { build(:phone_number, :nil_effective_date) }
  let(:now) { '2018-04-02T14:02:59+00:00' }

  describe '#set' do
    before { Timecop.freeze now }

    after { Timecop.return }

    it 'returns string of JSON nested in the passed pciu_key', :aggregate_failures do
      request_body = EVSS::PCIU::RequestBody.new(phone, pciu_key: 'phone')
      results      = request_body.set
      parsed       = JSON.parse results

      expect(results.class).to eq String
      expect(parsed).to eq(
        'phone' => {
          'countryCode' => '1',
          'number' => '4445551212',
          'extension' => '101',
          'effectiveDate' => '2018-04-02T14:02:59.000+00:00'
        }
      )
      expect(parsed.keys).to include 'phone'
    end

    it 'sets the passed date_attr to the current DateTime' do
      request_body   = EVSS::PCIU::RequestBody.new(phone, pciu_key: 'phone')
      effective_date = JSON.parse(request_body.set).dig('phone', 'effectiveDate')

      expect(effective_date.to_datetime).to eq now.to_datetime
    end

    it 'removes any empty attributes passed in the request_attrs' do
      phone        = build(:phone_number, :nil_effective_date, extension: '')
      request_body = EVSS::PCIU::RequestBody.new(phone, pciu_key: 'phone')
      extension    = JSON.parse(request_body.set).dig('phone', 'extension')

      expect(extension).to be_nil
    end
  end
end
