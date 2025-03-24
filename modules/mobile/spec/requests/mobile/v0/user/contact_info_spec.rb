# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
RSpec.describe 'Mobile::V0::User::ContactInfo', type: :request do
  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
  end

  let!(:user) { sis_user }
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

  describe 'GET /mobile/v0/user/contact_info with vet360 id', :skip_va_profile_user do
    context 'valid user' do
      before do
        get('/mobile/v0/user/contact-info', headers: sis_headers)
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
        expect(response.parsed_body.dig('data', 'id')).to eq(user.uuid)
      end
    end
  end

  describe 'GET /mobile/v0/user/contact_info without vet360 id', :skip_va_profile_user do
    let!(:user) { sis_user(vet360_id: nil) }

    before do
      get('/mobile/v0/user/contact-info', headers: sis_headers)
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
