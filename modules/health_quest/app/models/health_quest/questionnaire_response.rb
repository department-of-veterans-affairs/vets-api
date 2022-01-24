# frozen_string_literal: true

module HealthQuest
  ##
  # An ActiveRecord object for modeling and persisting questionnaire response and user demographics data to the DB.
  #
  # @!attribute appointment_id
  #   @return [String]
  # @!attribute user_uuid
  #   @return [String]
  # @!attribute questionnaire_response_id
  #   @return [String]
  # @!attribute questionnaire_response_data
  #   @return [String]
  # @!attribute user_demographics_data
  #   @return [String]
  # @!attribute user
  #   @return [User]
  class QuestionnaireResponse < ApplicationRecord
    attr_accessor :user

    serialize :questionnaire_response_data, JsonMarshaller
    serialize :user_demographics_data, JsonMarshaller
    has_kms_key
    encrypts :questionnaire_response_data, :user_demographics_data, key: :kms_key

    validates :questionnaire_response_data, presence: true

    before_save :set_user_demographics

    private

    ##
    # sets the users demographics as a snapshot when creating a
    # questionnaire response against lighthouse
    #
    def set_user_demographics
      contact_info = user.vet360_contact_info

      demographics = {
        first_name: user.first_name,
        middle_name: user.middle_name,
        last_name: user.last_name,
        gender: user.gender,
        date_of_birth: user.birth_date,
        address: user.address,
        mailing_address: contact_info&.mailing_address,
        home_address: contact_info&.residential_address,
        home_phone: contact_info&.home_phone,
        mobile_phone: contact_info&.mobile_phone,
        work_phone: contact_info&.work_phone
      }

      self.user_demographics_data = demographics
    end
  end
end
