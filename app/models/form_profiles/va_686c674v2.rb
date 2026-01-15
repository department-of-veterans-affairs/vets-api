# frozen_string_literal: true

require 'vets/model'
require 'bid/awards/service'

class FormProfiles::VA686c674v2 < FormProfile
  include PensionAwardHelper
  class DependentInformation
    include Vets::Model

    attribute :full_name, FormFullName
    attribute :date_of_birth, Date
    attribute :ssn, String
    attribute :relationship_to_veteran, String
    attribute :award_indicator, String
  end

  class FormAddress
    include Vets::Model

    attribute :country_name, String
    attribute :address_line1, String
    attribute :address_line2, String
    attribute :address_line3, String
    attribute :city, String
    attribute :state_code, String
    attribute :province, String
    attribute :zip_code, String
    attribute :international_postal_code, String
  end

  attribute :form_address, FormAddress
  attribute :dependents_information, DependentInformation, array: true

  def prefill
    prefill_form_address
    prefill_dependents_information

    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/686-options-selection'
    }
  end

  private

  def prefill_form_address
    begin
      mailing_address = VAProfileRedis::V2::ContactInformation.for_user(user).mailing_address
    rescue
      nil
    end

    return if mailing_address.blank?

    zip_code = mailing_address.zip_code.presence || mailing_address.international_postal_code.presence
    @form_address = FormAddress.new(
      mailing_address.to_h.slice(
        :address_line1, :address_line2, :address_line3,
        :city, :state_code, :province
      ).merge(country_name: mailing_address.country_code_iso3, zip_code:)
    )
  end

  def va_file_number_last_four
    response = BGS::People::Request.new.find_person_by_participant_id(user:)
    (
      response.file_number.presence || user.ssn.presence
    )&.last(4)
  end

  ##
  # This method retrieves the dependents from the BGS service and maps them to the DependentInformation model.
  # If no dependents are found or if they are not active for benefits, it returns an empty array.
  def prefill_dependents_information
    dependents = dependent_service.get_dependents
    persons = if dependents.blank? || dependents[:persons].blank?
                []
              else
                dependents[:persons]
              end
    @dependents_information = persons.filter_map do |person|
      person_to_dependent_information(person)
    end
    if Flipper.enabled?(:va_dependents_v3, user)
      @dependents_information = { success: 'true', dependents: @dependents_information }
    else
      @dependents_information
    end
  rescue => e
    monitor.track_event('warn', 'Failure initializing dependents_information', 'dependents.prefill.error',
                        { error: e&.message })
    @dependents_information = Flipper.enabled?(:va_dependents_v3, user) ? { success: 'false', dependents: [] } : []
  end

  ##
  # Assigns a dependent's information to the DependentInformation model.
  #
  # @param person [Hash] The dependent's information as a hash
  # @return [DependentInformation] The dependent's information mapped to the model
  def person_to_dependent_information(person)
    first_name = person[:first_name]
    last_name = person[:last_name]
    middle_name = person[:middle_name]
    ssn = person[:ssn]
    date_of_birth = person[:date_of_birth]
    relationship = person[:relationship]
    award_indicator = person[:award_indicator]

    parsed_date = parse_date_safely(date_of_birth)

    DependentInformation.new(
      full_name: FormFullName.new({
                                    first: first_name,
                                    middle: middle_name,
                                    last: last_name
                                  }),
      date_of_birth: parsed_date,
      ssn:,
      relationship_to_veteran: relationship,
      award_indicator:
    )
  end

  def dependent_service
    @dependent_service ||= BGS::DependentV2Service.new(user)
  end

  def pension_award_service
    @pension_award_service ||= BID::Awards::Service.new(user)
  end

  def monitor
    @monitor ||= Dependents::Monitor.new(nil)
  end

  ##
  # Implementation of abstract method from PensionAwardHelper
  # Tracks pension award errors using the monitor service
  #
  # @param error [Exception] The error that occurred during pension award retrieval
  def track_pension_award_error(error)
    monitor.track_event('warn', 'Failed to retrieve awards pension data', 'awards_pension_error', {
                          user_account_uuid: user&.user_account_uuid,
                          error: error.message,
                          form_id:
                        })
  end

  ##
  # Safely parses a date string, handling various formats
  #
  # @param date_string [String, Date, nil] The date to parse
  # @return [Date, nil] The parsed date or nil if parsing fails
  def parse_date_safely(date_string)
    return nil if date_string.blank?

    return date_string if date_string.is_a?(Date)

    Date.strptime(date_string.to_s, '%m/%d/%Y')
  rescue ArgumentError, TypeError
    nil
  end
end
