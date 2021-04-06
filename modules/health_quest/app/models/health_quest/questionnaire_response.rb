# frozen_string_literal: true

require 'json_marshal/marshaller'

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

    attr_encrypted :questionnaire_response_data,
                   key: Settings.db_encryption_key,
                   marshal: true,
                   marshaler: JsonMarshal::Marshaller
    attr_encrypted :user_demographics_data,
                   key: Settings.db_encryption_key,
                   marshal: true,
                   marshaler: JsonMarshal::Marshaller

    validates :questionnaire_response_data, presence: true

    before_save :set_user_demographics

    private

    def set_user_demographics
      demographics = {
        first_name: user.first_name,
        middle_name: user.middle_name,
        last_name: user.last_name,
        gender: user.gender,
        address: user.address,
        vas_contact_info: user.vet360_contact_info
      }

      self.user_demographics_data = demographics
    end
  end
end
