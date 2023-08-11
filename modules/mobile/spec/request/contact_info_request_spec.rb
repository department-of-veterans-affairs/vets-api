# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

RSpec.describe 'contact info', type: :request do
  include SchemaMatchers

  let(:attributes) { response.parsed_body.dig('data', 'attributes') }

  let(:residential_address) do
    {
      'id' => 123,
      'addressLine1' => '140 Rock Creek Rd',
      'addressLine2' => nil,
      'addressLine3' => nil,
      'addressPou' => 'RESIDENCE/CHOICE',
      'addressType' => 'DOMESTIC',
      'city' => 'Washington',
      'countryName' => 'USA',
      'countryCodeIso2' => nil,
      'countryCodeIso3' => 'USA',
      'countryCodeFips' => nil,
      'countyCode' => nil,
      'countyName' => nil,
      'createdAt' => '2017-04-09T11:52:03.000-06:00',
      'effectiveEndDate' => nil,
      'effectiveStartDate' => nil,
      'geocodeDate' => '2018-04-13T17:01:18.000Z',
      'geocodePrecision' => 100.0,
      'internationalPostalCode' => nil,
      'latitude' => 38.901,
      'longitude' => -77.0347,
      'province' => nil,
      'sourceDate' => '2018-04-09T11:52:03.000-06:00',
      'sourceSystemUser' => nil,
      'stateCode' => 'DC',
      'updatedAt' => '2017-04-09T11:52:03.000-06:00',
      'validationKey' => nil,
      'vet360Id' => '12345',
      'zipCode' => '20011',
      'zipCodeSuffix' => nil,
      'badAddress' => true
    }
  end

  let(:mailing_address) do
    {
      'addressLine1' => '140 Rock Creek Rd',
      'addressLine2' => nil,
      'addressLine3' => nil,
      'addressPou' => 'CORRESPONDENCE',
      'addressType' => 'DOMESTIC',
      'city' => 'Washington',
      'countryName' => 'USA',
      'countryCodeIso2' => nil,
      'countryCodeIso3' => 'USA',
      'countryCodeFips' => nil,
      'countyCode' => nil,
      'countyName' => nil,
      'createdAt' => '2017-04-09T11:52:03.000-06:00',
      'effectiveEndDate' => nil,
      'effectiveStartDate' => nil,
      'geocodeDate' => '2018-04-13T17:01:18.000Z',
      'geocodePrecision' => 100.0,
      'id' => 124,
      'internationalPostalCode' => nil,
      'latitude' => 38.901,
      'longitude' => -77.0347,
      'province' => nil,
      'sourceDate' => '2018-04-09T11:52:03.000-06:00',
      'sourceSystemUser' => nil,
      'stateCode' => 'DC',
      'updatedAt' => '2017-04-09T11:52:03.000-06:00',
      'validationKey' => nil,
      'vet360Id' => '12345',
      'zipCode' => '20011',
      'zipCodeSuffix' => nil,
      'badAddress' => true

    }
  end

  let(:home_phone) do
    {
      'areaCode' => '303',
      'countryCode' => '1',
      'createdAt' => '2017-04-09T11:52:03.000-06:00',
      'extension' => nil,
      'effectiveEndDate' => nil,
      'effectiveStartDate' => nil,
      'id' => 789,
      'isInternational' => false,
      'isTextable' => false,
      'isTextPermitted' => false,
      'isTty' => true,
      'isVoicemailable' => true,
      'phoneNumber' => '5551234',
      'phoneType' => 'HOME',
      'sourceDate' => '2018-04-09T11:52:03.000-06:00',
      'sourceSystemUser' => nil,
      'updatedAt' => '2017-04-09T11:52:03.000-06:00',
      'vet360Id' => '12345'
    }
  end

  let(:mobile_phone) do
    {
      'areaCode' => '303',
      'countryCode' => '1',
      'createdAt' => '2017-04-09T11:52:03.000-06:00',
      'extension' => nil,
      'effectiveEndDate' => nil,
      'effectiveStartDate' => nil,
      'id' => 790,
      'isInternational' => false,
      'isTextable' => false,
      'isTextPermitted' => false,
      'isTty' => true,
      'isVoicemailable' => true,
      'phoneNumber' => '5551234',
      'phoneType' => 'MOBILE',
      'sourceDate' => '2018-04-09T11:52:03.000-06:00',
      'sourceSystemUser' => nil,
      'updatedAt' => '2017-04-09T11:52:03.000-06:00',
      'vet360Id' => '12345'
    }
  end

  let(:work_phone) do
    {
      'areaCode' => '303',
      'countryCode' => '1',
      'createdAt' => '2017-04-09T11:52:03.000-06:00',
      'extension' => nil,
      'effectiveEndDate' => nil,
      'effectiveStartDate' => nil,
      'id' => 791,
      'isInternational' => false,
      'isTextable' => false,
      'isTextPermitted' => false,
      'isTty' => true,
      'isVoicemailable' => true,
      'phoneNumber' => '5551234',
      'phoneType' => 'WORK',
      'sourceDate' => '2018-04-09T11:52:03.000-06:00',
      'sourceSystemUser' => nil,
      'updatedAt' => '2017-04-09T11:52:03.000-06:00',
      'vet360Id' => '12345'
    }
  end

  let(:user) { FactoryBot.build(:iam_user) }

  before do
    iam_sign_in(user)
  end

  describe 'GET /mobile/v0/user/contact_info with vet360 id' do
    context 'valid user' do
      before do
        get('/mobile/v0/user/contact-info', headers: iam_headers)
      end

      it 'returns full contact information' do
        expect(attributes['residentialAddress']).to include(residential_address)
        expect(attributes['mailingAddress']).to include(mailing_address)
        expect(attributes['homePhone']).to include(home_phone)
        expect(attributes['mobilePhone']).to include(mobile_phone)
        expect(attributes['workPhone']).to include(work_phone)
      end

      it 'returns the user id' do
        expect(response.parsed_body.dig('data', 'id')).to eq(user.id)
      end
    end
  end

  describe 'GET /mobile/v0/user/contact_info without vet360 id' do
    before do
      allow_any_instance_of(IAMUser).to receive(:vet360_id).and_return(nil)

      get('/mobile/v0/user/contact-info', headers: iam_headers)
    end

    it 'returns nil' do
      expect(attributes['residentialAddress']).to be_nil
      expect(attributes['mailingAddress']).to be_nil
      expect(attributes['homePhone']).to be_nil
      expect(attributes['mobilePhone']).to be_nil
      expect(attributes['workPhone']).to be_nil
    end
  end
end
