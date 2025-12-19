# frozen_string_literal: true

require 'vets/model'

module MHVAC
  ##
  # Models a MHVAC (MyHealtheVet Account Creation) registration form.
  # This class is used to store form details and to generate the request for
  # submission to the MHV service.
  #
  # @!attribute icn
  #   @return [String] registrant's ICN (Integration Control Number)
  # @!attribute is_patient
  #   @return [Boolean]
  # @!attribute is_patient_advocate
  #   @return [Boolean]
  # @!attribute is_veteran
  #   @return [Boolean]
  # @!attribute is_champ_VA_beneficiary
  #   @return [Boolean]
  # @!attribute is_service_member
  #   @return [Boolean]
  # @!attribute is_employee
  #   @return [Boolean]
  # @!attribute is_health_care_provider
  #   @return [Boolean]
  # @!attribute is_other
  #   @return [Boolean]
  # @!attribute address1
  #   @return [String] registrant's address line 1
  # @!attribute address2
  #   @return [String] registrant's address line 2
  # @!attribute city
  #   @return [String] registrant's city
  # @!attribute state
  #   @return [String] registrant's state
  # @!attribute zip
  #   @return [String] registrant's zip
  # @!attribute country
  #   @return [String] registrant's country
  # @!attribute province
  #   @return [String] registrant's province
  # @!attribute contact_method
  #   @return [String]  registrant's preferred contact method
  # @!attribute email
  #   @return [String] registrant's email address
  # @!attribute fax
  #   @return [String] registrant's fax number
  # @!attribute home_phone
  #   @return [String] registrant's home phone number
  # @!attribute mobile_phone
  #   @return [String] registrant's mobile phone number
  # @!attribute pager
  #   @return [String] registrant's pager phone number
  # @!attribute work_phone
  #   @return [String] registrant's work phone number
  # @!attribute sign_in_partners
  #   @return [String] which sign in partner the registrant is using
  # @!attribute terms_version
  #   @return [String] the version of terms of agreement that the registrant recieved
  # @!attribute terms_accepted_date
  #   @return [Vets::Type::HTTPDate] date the registrant accepted the terms of agreement
  #
  class RegistrationForm
    include Vets::Model

    attribute :icn, String
    attribute :is_patient, Bool
    attribute :is_patient_advocate, Bool
    attribute :is_veteran, Bool
    attribute :is_champ_VA_beneficiary, Bool
    attribute :is_service_member, Bool
    attribute :is_employee, Bool
    attribute :is_health_care_provider, Bool
    attribute :is_other, Bool
    attribute :address1, String
    attribute :address2, String
    attribute :city, String
    attribute :state, String
    attribute :zip, String
    attribute :country, String
    attribute :province, String
    attribute :contact_method, String
    attribute :email, String
    attribute :fax, String
    attribute :home_phone, String
    attribute :mobile_phone, String
    attribute :pager, String
    attribute :work_phone, String
    attribute :sign_in_partners, String
    attribute :terms_version, String
    attribute :terms_accepted_date, Vets::Type::HTTPDate

    ##
    # Validates form attributes and wraps each present attribute to create
    # a parameter set for MHV, stripping attribute values of nil.
    #
    # @raise [Common::Exceptions::ValidationErrors] if there are validation errors
    # @return [Hash] A hash of valid form attributes
    #
    def mhv_params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      self.class.attribute_set.map do |attribute|
        value = send(attribute.name)
        [attribute.name, value] unless value.nil?
      end.compact.to_h
    end
  end
end
