# frozen_string_literal: true

module AppealsApi
  class HigherLevelReview < ApplicationRecord
    class << self
      def date_from_string(string)
        string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
      rescue ArgumentError
        nil
      end

      def past?(date)
        date < Time.zone.today
      end
    end

    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    enum status: { pending: 0, processing: 1, submitted: 2, established: 3, error: 4 }

    INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_NUMBER_MAX_LENGTH = 100
    NO_ADDRESS_PROVIDED_SENTENCE = 'USE ADDRESS ON FILE'

    # the controller applies the JSON Schemas in modules/appeals_api/config/schemas/
    # further validations:
    validate(
      :veteran_phone_is_not_too_long,
      :informal_conference_rep_name_and_phone_number_is_not_too_long,
      :birth_date_is_a_date,
      :birth_date_is_in_the_past,
      :contestable_issue_dates_are_valid_dates
    )

    # 1. VETERAN'S NAME
    def first_name
      header_field_as_string 'X-VA-First-Name'
    end

    def middle_initial
      header_field_as_string 'X-VA-Middle-Initial'
    end

    def last_name
      header_field_as_string 'X-VA-Last-Name'
    end

    def full_name
      "#{first_name} #{middle_initial} #{last_name}".squeeze(' ').strip
    end

    # 2. VETERAN'S SOCIAL SECURITY NUMBER
    def ssn
      header_field_as_string 'X-VA-SSN'
    end

    # 3. VA FILE NUMBER
    def file_number
      header_field_as_string 'X-VA-File-Number'
    end

    # 4. VETERAN'S DATE OF BIRTH
    def birth_mm
      birth_date.strftime '%m'
    end

    def birth_dd
      birth_date.strftime '%d'
    end

    def birth_yyyy
      birth_date.strftime '%Y'
    end

    # 5. VETERAN'S SERVICE NUMBER
    def service_number
      header_field_as_string 'X-VA-Service-Number'
    end

    # 6. INSURANCE POLICY NUMBER
    def insurance_policy_number
      header_field_as_string 'X-VA-Insurance-Policy-Number'
    end

    # 7. CLAIMANT'S NAME
    # 8. CLAIMANT TYPE

    # 9. CURRENT MAILING ADDRESS
    def number_and_street
      return NO_ADDRESS_PROVIDED_SENTENCE if address_blank?

      address_field_as_string 'addressLine1'
    end

    def apt_unit_number
      address_field_as_string 'addressLine2'
    end

    def city
      address_field_as_string 'cityName'
    end

    def state_code
      address_field_as_string 'stateCode'
    end

    def country_code
      address_field_as_string 'countryCodeISO2' || 'US'
    end

    def zip_code_5
      address_field_as_string 'zipCode5'
    end

    def zip_code_4
      address_field_as_string 'zipCode4'
    end

    # 10. TELEPHONE NUMBER
    def veteran_phone_number
      veteran_phone.to_s
    end

    # 11. E-MAIL ADDRESS
    def email
      veteran&.dig('emailAddressText').to_s.strip
    end

    # 12. BENEFIT TYPE
    def benefit_type
      data_attributes&.dig('benefitType').to_s.strip
    end

    # 13. IF YOU WOULD LIKE THE SAME OFFICE...
    def same_office?
      data_attributes&.dig('sameOffice')
    end

    # 14. ...INFORMAL CONFERENCE...
    def informal_conference?
      data_attributes&.dig('informalConference')
    end

    def informal_conference_times
      data_attributes&.dig('informalConferenceTimes')
    end

    def informal_conference_rep_name_and_phone_number
      "#{informal_conference_rep_name} #{informal_conference_rep_phone}"
    end

    # 15. YOU MUST INDICATE BELOW EACH ISSUE...
    def contestable_issues
      form_data&.dig('included')
    end

    def consumer_name
      auth_headers['X-Consumer-Username']
    end

    def consumer_id
      auth_headers['X-Consumer-ID']
    end

    def central_mail_status
      CentralMail::Service.new.status(id)
    end

    private

    def data_attributes
      form_data&.dig('data', 'attributes')
    end

    def veteran
      data_attributes&.dig('veteran')
    end

    def address_field_as_string(key)
      veteran&.dig('address', key).to_s.strip
    end

    def birth_date_string
      header_field_as_string 'X-VA-Birth-Date'
    end

    def birth_date
      self.class.date_from_string birth_date_string
    end

    def veteran_phone
      AppealsApi::HigherLevelReview::Phone.new veteran&.dig('phone')
    end

    def informal_conference_rep
      data_attributes&.dig('informalConferenceRep')
    end

    def informal_conference_rep_name
      informal_conference_rep&.dig('name')
    end

    def informal_conference_rep_phone
      AppealsApi::HigherLevelReview::Phone.new informal_conference_rep&.dig('phone')
    end

    def header_field_as_string(key)
      auth_headers&.dig(key).to_s.strip
    end

    # validation
    def veteran_phone_is_not_too_long
      add_error(veteran_phone.too_long_error_message) if veteran_phone.too_long?
    end

    # validation
    def informal_conference_rep_name_and_phone_number_is_not_too_long
      return unless informal_conference_rep_name_and_phone_number_is_too_long?

      add_error_informal_conference_rep_will_not_fit_on_form
    end

    def informal_conference_rep_name_and_phone_number_is_too_long?
      informal_conference_rep_name_and_phone_number.length >
        INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_NUMBER_MAX_LENGTH
    end

    def add_error_informal_conference_rep_will_not_fit_on_form
      add_error [
        'Informal conference rep will not fit on form',
        "(#{INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_NUMBER_MAX_LENGTH} char limit):",
        informal_conference_rep_name_and_phone_number
      ].join(' ')
    end

    # validation (header)
    def birth_date_is_a_date
      add_error("Veteran birth date isn't a date: #{birth_date_string.inspect}") unless birth_date
    end

    # validation (header)
    def birth_date_is_in_the_past
      return unless birth_date

      add_error("Veteran birth date isn't in the past: #{birth_date}") unless self.class.past? birth_date
    end

    # validation
    def contestable_issue_dates_are_valid_dates
      return unless contestable_issues

      contestable_issues.each_with_index do |ci, index|
        decision_date_is_valid(ci&.dig('attributes', 'decisionDate').to_s, index)
      end
    end

    def decision_date_is_valid(string, issue_index)
      date = self.class.date_from_string(string)
      unless date
        add_error_decision_date_string_could_not_be_parsed(string, issue_index)
        return
      end
      add_error_decision_date_is_not_in_the_past(date, issue_index) unless self.class.past? date
    end

    def add_error_decision_date_string_could_not_be_parsed(decision_date_string, issue_index)
      add_decision_date_error "isn't a valid date: #{decision_date_string.inspect}", issue_index
    end

    def add_error_decision_date_is_not_in_the_past(decision_date, issue_index)
      add_decision_date_error "isn't in the past: #{decision_date}", issue_index
    end

    def add_decision_date_error(string, issue_index)
      add_error "included[#{issue_index}].attributes.decisionDate #{string}"
    end

    def add_error(message)
      errors.add(:base, message)
    end

    def address_present?
      address = veteran&.dig 'address'
      address.is_a?(Hash) && address.values.any?(&:present?)
    end

    def address_blank?
      !address_present?
    end
  end
end
