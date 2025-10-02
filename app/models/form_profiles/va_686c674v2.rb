# frozen_string_literal: true

require 'vets/model'
require 'bid/awards/service'

class FormProfiles::VA686c674v2 < FormProfile
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

    @form_address = FormAddress.new(
      mailing_address.to_h.slice(
        :address_line1, :address_line2, :address_line3,
        :city, :state_code, :province,
        :zip_code, :international_postal_code
      ).merge(country_name: mailing_address.country_code_iso3)
    )
  end

  def va_file_number_last_four
    response = BGS::People::Request.new.find_person_by_participant_id(user:)
    (
      response.file_number.presence || user.ssn.presence
    )&.last(4)
  end

  # @return [Integer] 1 if user is in receipt of pension, 0 if not, -1 if request fails
  # Needed for FE to differentiate between 200 response and error
  def is_in_receipt_of_pension # rubocop:disable Naming/PredicatePrefix
    case awards_pension[:is_in_receipt_of_pension]
    when true
      1
    when false
      0
    else
      -1
    end
  end

  # @return [Integer] the net worth limit for pension, default is 159240 as of 2025
  # Default will be cached in future enhancement
  def net_worth_limit
    awards_pension[:net_worth_limit] || 159240 # rubocop:disable Style/NumericLiterals
  end

  # @return [Hash] the awards pension data from BID service or an empty hash if the request fails
  def awards_pension
    @awards_pension ||= begin
      response = pension_award_service.get_awards_pension
      response.try(:body)&.dig('awards_pension')&.transform_keys(&:to_sym)
    rescue => e
      payload = {
        user_account_uuid: user&.user_account_uuid,
        error: e.message,
        form_id:
      }
      Rails.logger.warn('Failed to retrieve awards pension data', payload)
      {}
    end
  end

  ##
  # This method retrieves the dependents from the BGS service and maps them to the DependentInformation model.
  # If no dependents are found or if they are not active for benefits, it returns an empty array.
  def prefill_dependents_information
    dependents = dependent_service.get_dependents
    # Temporary tracking to understand data structure during failures
    monitor.track_event(
      'info',
      "Get dependents data: #{dependents.class}",
      'dependents.data.structure',
      { dependents: }
    )
    persons = if dependents.nil? || dependents[:persons].blank?
                []
              else
                dependents[:persons]
              end
    @dependents_information = persons.filter_map do |person|
      person_to_dependent_information(person)
    end
  rescue => e
    monitor.track_event('warn', 'Failure initializing dependents_information', 'dependents.prefill.error',
                        { error: e&.message })
    @dependents_information = []
  end

  ##
  # Assigns a dependent's information to the DependentInformation model.
  #
  # @param person [Hash] The dependent's information as a hash
  # @return [DependentInformation] The dependent's information mapped to the model
  def person_to_dependent_information(person)
    return nil unless person.respond_to?(:[])

    # Try both symbol and string keys
    first_name = person[:first_name] || person['first_name']
    last_name = person[:last_name] || person['last_name']
    middle_name = person[:middle_name] || person['middle_name']
    ssn = person[:ssn] || person['ssn']
    date_of_birth = person[:date_of_birth] || person['date_of_birth']
    relationship = person[:relationship] || person['relationship']
    award_indicator = person[:award_indicator] || person['award_indicator']

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
    @dependent_service ||= BGS::DependentService.new(user)
  end

  def pension_award_service
    @pension_award_service ||= BID::Awards::Service.new(user)
  end

  def monitor
    @monitor ||= Dependents::Monitor.new(nil)
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
