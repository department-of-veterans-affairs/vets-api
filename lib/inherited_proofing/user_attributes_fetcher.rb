# frozen_string_literal: true

require 'inherited_proofing/errors'

module InheritedProofing
  class UserAttributesFetcher
    attr_reader :auth_code

    def initialize(auth_code:)
      @auth_code = auth_code
    end

    def perform
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
      user.address[:street] && user.address[:zip]
    end

    def user_attributes
      @user_attributes ||= {
        first_name: user.first_name,
        last_name: user.last_name,
        address: user.address,
        phone: user.home_phone,
        birth_date: user.birth_date,
        ssn: user.ssn
      }
    end
  end
end
