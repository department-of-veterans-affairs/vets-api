# frozen_string_literal: true

require 'vets/model'
require 'lighthouse/benefits_education/enrollment'
require 'lighthouse/benefits_education/entitlement'
require 'vets/shared_logging'

module BenefitsEducation
  ##
  # Model for the GIBS status response
  #
  # @!attribute first_name
  #   @return [String] User's first name
  # @!attribute last_name
  #   @return [String] User's last name
  # @!attribute name_suffix
  #   @retun [String] User's suffix
  # @!attribute date_of_birth
  #   @return [String] User's date of birth
  # @!attribute va_file_number
  #   @return [String] User's VA file number
  # @!attribute regional_processing_office
  #   @return [String] Closest processing office to the user
  # @!attribute eligibility_date
  #   @return [String] The date at which benefits are eligible to be paid
  # @!attribute delimiting_date
  #   @return [String] The date after which benefits cannot be paid
  # @!attribute percentage_benefit
  #   @return [Integer] The amount of the benefit the user is eligible for
  # @!attribute original_entitlement
  #   @return [Entitlement] The time span of the user's original entitlement
  # @!attribute used_entitlement
  #   @return [Entitlement] The amount of entitlement time the user has already used
  # @!attribute remaining_entitlement
  #   @return [Entitlement] The amount of entitlement time the user has remaining
  # @!attribute veteran_is_eligible
  #   @return [Boolean] Is the user eligbile for the benefit
  # @!attribute active_duty
  #   @return [Boolean] Is the user on active duty
  # @!attribute enrollments
  #   @return [Array[Enrollment]] An array of the user's enrollments
  class Response
    include Vets::Model
    include Vets::SharedLogging

    attribute :first_name, String
    attribute :last_name, String
    attribute :name_suffix, String
    attribute :date_of_birth, String
    attribute :va_file_number, String
    attribute :regional_processing_office, String
    attribute :eligibility_date, String
    attribute :delimiting_date, String
    attribute :percentage_benefit, Integer
    attribute :original_entitlement, Entitlement
    attribute :used_entitlement, Entitlement
    attribute :remaining_entitlement, Entitlement
    attribute :veteran_is_eligible, Bool
    attribute :active_duty, Bool
    attribute :enrollments, Enrollment, array: true

    def initialize(_status, response = nil)
      @response = response
      key_mapping = { 'eligibility_date_time' => 'eligibility_date', 'delimiting_date_time' => 'delimiting_date',
                      'date_time_of_birth' => 'date_of_birth' }
      attributes = if contains_education_info?
                     response.body['chapter33EducationInfo'].deep_transform_keys!(&:underscore)
                   else
                     {}
                   end
      attributes.transform_keys! { |key| key_mapping[key] || key }
      super(attributes)
    end

    def contains_education_info?
      return false if @response.nil?

      @response.body.key?('chapter33EducationInfo') == true &&
        @response.body['chapter33EducationInfo'] != {} &&
        !@response.body['chapter33EducationInfo'].nil?
    end
  end
end
