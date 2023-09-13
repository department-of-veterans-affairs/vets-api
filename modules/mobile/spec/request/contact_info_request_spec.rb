# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

RSpec.describe 'contact info', type: :request do
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
      'countryCodeIso3' => 'USA',
      'internationalPostalCode' => nil,
      'province' => nil,
      'stateCode' => 'DC',
      'zipCode' => '20011',
      'zipCodeSuffix' => nil
    }
  end

  let(:mailing_address) do
    {
      'id' => 124,
      'addressLine1' => '140 Rock Creek Rd',
      'addressLine2' => nil,
      'addressLine3' => nil,
      'addressPou' => 'CORRESPONDENCE',
      'addressType' => 'DOMESTIC',
      'city' => 'Washington',
      'countryName' => 'USA',
      'countryCodeIso3' => 'USA',
      'internationalPostalCode' => nil,
      'province' => nil,
      'stateCode' => 'DC',
      'zipCode' => '20011',
      'zipCodeSuffix' => nil

    }
  end

  let(:home_phone) do
    {
      'id' => 789,
      'areaCode' => '303',
      'countryCode' => '1',
      'extension' => nil,
      'phoneNumber' => '5551234',
      'phoneType' => 'HOME'
    }
  end

  let(:mobile_phone) do
    {
      'id' => 790,
      'areaCode' => '303',
      'countryCode' => '1',
      'extension' => nil,
      'phoneNumber' => '5551234',
      'phoneType' => 'MOBILE'
    }
  end

  let(:work_phone) do
    {
      'id' => 791,
      'areaCode' => '303',
      'countryCode' => '1',
      'extension' => nil,
      'phoneNumber' => '5551234',
      'phoneType' => 'WORK'
    }
  end

  let(:contact_email) do
    {
      'id' => 456,
      'emailAddress' => user.vet360_contact_info.email.email_address # dynamic value
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
        expect(attributes['residentialAddress']).to eq(residential_address)
        expect(attributes['mailingAddress']).to eq(mailing_address)
        expect(attributes['homePhone']).to eq(home_phone)
        expect(attributes['mobilePhone']).to eq(mobile_phone)
        expect(attributes['workPhone']).to eq(work_phone)
        expect(attributes['contactEmail']).to eq(contact_email)
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
      expect(attributes['contactEmail']).to be_nil
    end
  end
end
