# frozen_string_literal: true

require 'inherited_proofing/errors'

module InheritedProofing
  class UserAttributesFetcher
    attr_reader :auth_code

    def initialize(auth_code:)
      @auth_code = auth_code
    end

    def perform
      return mocked_user_attributes if auth_code == mocked_auth_code

      validations
      user_attributes
    ensure
      mhv_identity_data&.destroy
    end

    private

    def validations
      raise Errors::MHVIdentityDataNotFoundError unless mhv_identity_data
      raise Errors::UserNotFoundError unless user
      raise Errors::UserMissingAttributesError unless required_attributes_present?
    end

    def mhv_identity_data
      @mhv_identity_data ||= InheritedProofing::MHVIdentityData.find(auth_code)
    end

    def user
      @user ||= User.find(mhv_identity_data.user_uuid)
    end

    def required_attributes_present?
      user.first_name && user.last_name && user.birth_date && user.ssn && address_present?
    end

    def address_present?
      user.address[:street] && user.address[:postal_code]
    end

    def user_attributes
      @user_attributes ||= {
        first_name: user.first_name,
        last_name: user.last_name,
        address: user.address,
        phone: user.home_phone,
        birth_date: user.birth_date,
        ssn: user.ssn,
        mhv_data: mhv_identity_data.data
      }
    end

    def mocked_auth_code
      'mocked-auth-code-for-testing'
    end

    def mocked_user_attributes
      {
        first_name: 'Fakey',
        last_name: 'Fakerson',
        address: mocked_address,
        phone: '2063119187',
        birth_date: '2022-1-31',
        ssn: '123456789',
        mhv_data: mocked_mhv_data
      }
    end

    def mocked_address
      {
        street: '123 Fake St',
        street2: 'Apt 235',
        city: 'Faketown',
        state: 'WA',
        country: nil,
        zip: '98037'
      }
    end

    def mocked_mhv_data
      {
        'mhvId' => 99_999_999,
        'identityProofedMethod' => 'IPA',
        'identityDocumentExist' => true,
        'identityProofingDate' => '2020-12-14',
        'identityDocumentInfo' => {
          'primaryIdentityDocumentNumber' => '88888888',
          'primaryIdentityDocumentType' => 'StateIssuedId',
          'primaryIdentityDocumentCountry' => 'United States',
          'primaryIdentityDocumentExpirationDate' => '2222-03-30'
        }
      }
    end
  end
end
