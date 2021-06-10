# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'common/exceptions'

module AppealsApi
  class HigherLevelReview < ApplicationRecord
    include HlrStatus

    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    INFORMAL_CONFERENCE_REP_NAME_AND_PHONE_NUMBER_MAX_LENGTH = 100
    NO_ADDRESS_PROVIDED_SENTENCE = 'USE ADDRESS ON FILE'
    NO_EMAIL_PROVIDED_SENTENCE = 'USE EMAIL ON FILE'
    NO_PHONE_PROVIDED_SENTENCE = 'USE PHONE ON FILE'

    # the controller applies the JSON Schemas in modules/appeals_api/config/schemas/
    # further validations:
    validate(
      :veteran_phone_is_not_too_long,
      :informal_conference_rep_name_and_phone_number_is_not_too_long,
      :birth_date_is_a_date,
      :birth_date_is_in_the_past,
      :contestable_issue_dates_are_valid_dates,
      if: proc { |a| a.form_data.present? }
    )

    has_many :evidence_submissions, as: :supportable, dependent: :destroy
    has_many :status_updates, as: :statusable, dependent: :destroy

    def pdf_structure
      Object.const_get(
        "AppealsApi::PdfConstruction::HigherLevelReview::#{pdf_version.upcase}::Structure"
      ).new(self)
    end

    def formatter
      @formatter ||= AppealsApi::HigherLevelReviews::Formatter.new(self)
    end

    # 1. VETERAN'S NAME
    def first_name
      auth_headers.dig('X-VA-First-Name')
    end

    def middle_initial
      auth_headers.dig('X-VA-Middle-Initial')
    end

    def last_name
      auth_headers.dig('X-VA-Last-Name')
    end

    def full_name
      "#{first_name} #{middle_initial} #{last_name}".squeeze(' ').strip
    end

    # 2. VETERAN'S SOCIAL SECURITY NUMBER
    def ssn
      auth_headers.dig('X-VA-SSN')
    end

    # 3. VA FILE NUMBER
    def file_number
      auth_headers.dig('X-VA-File-Number')
    end

    # 5. VETERAN'S SERVICE NUMBER
    def service_number
      auth_headers.dig('X-VA-Service-Number')
    end

    # 6. INSURANCE POLICY NUMBER
    def insurance_policy_number
      auth_headers.dig('X-VA-Insurance-Policy-Number')
    end

    # 7. CLAIMANT'S NAME
    # 8. CLAIMANT TYPE

    # 9. CURRENT MAILING ADDRESS
    def number_and_street
      address_combined || 'USE ADDRESS ON FILE'
    end

    def city
      veteran.dig('address', 'city') || ''
    end

    def state_code
      veteran.dig('address', 'stateCode') || ''
    end

    def country_code
      return '' unless address_combined

      veteran.dig('address', 'countryCodeISO2') || 'US'
    end

    def zip_code_5
      veteran.dig('address', 'zipCode5') || '00000'
    end

    # 10. TELEPHONE NUMBER
    def veteran_phone_number
      veteran_phone.to_s
    end

    def veteran_phone_data
      veteran&.dig('phone')
    end

    def veteran_homeless?
      form_data&.dig('data', 'attributes', 'veteran', 'homeless')
    end

    # 11. E-MAIL ADDRESS
    def email
      veteran&.dig('emailAddressText').to_s.strip
    end

    def email_v2
      veteran&.dig('email').to_s.strip
    end

    # 12. BENEFIT TYPE
    def benefit_type
      data_attributes&.dig('benefitType').to_s.strip
    end

    # 13. IF YOU WOULD LIKE THE SAME OFFICE...
    def same_office
      data_attributes&.dig('sameOffice')
    end

    # 14. ...INFORMAL CONFERENCE...
    def informal_conference
      data_attributes&.dig('informalConference')
    end

    def informal_conference_times
      data_attributes&.dig('informalConferenceTimes') || []
    end

    def informal_conference_rep_name_and_phone_number
      "#{informal_conference_rep_name} #{informal_conference_rep_phone}"
    end

    def informal_conference_rep_phone_number
      informal_conference_rep_phone.to_s
    end

    def informal_conference_rep_ext
      informal_conference_rep&.dig('phone', 'phoneNumberExt')
    end

    def informal_conference_contact
      data_attributes&.dig('informalConferenceContact')
    end

    # V2 only allows one choice of conference time
    def informal_conference_time
      data_attributes&.dig('informalConferenceTime')
    end

    def rep_phone_data
      informal_conference_rep&.dig('phone')
    end

    def soc_opt_in
      data_attributes&.dig('socOptIn')
    end

    # 15. YOU MUST INDICATE BELOW EACH ISSUE...
    def contestable_issues
      @contestable_issues ||= formatter.contestable_issues
    end

    def consumer_name
      auth_headers&.dig('X-Consumer-Username')
    end

    def consumer_id
      auth_headers&.dig('X-Consumer-ID')
    end

    def update_status!(status:, code: nil, detail: nil)
      handler = Events::Handler.new(event_type: :hlr_status_updated, opts: {
                                      from: self.status,
                                      to: status,
                                      status_update_time: Time.zone.now,
                                      statusable_id: id
                                    })

      update!(status: status, code: code, detail: detail)

      handler.handle!
    end

    def informal_conference_rep
      data_attributes&.dig('informalConferenceRep')
    end

    delegate :birth_date, to: :formatter

    delegate :date_signed, to: :formatter

    private

    def data_attributes
      form_data&.dig('data', 'attributes')
    end

    def veteran
      data_attributes&.dig('veteran')
    end

    def veteran_phone
      AppealsApi::HigherLevelReview::Phone.new veteran&.dig('phone')
    end

    def informal_conference_rep_name
      informal_conference_rep&.dig('name')
    end

    def informal_conference_rep_phone
      AppealsApi::HigherLevelReview::Phone.new informal_conference_rep&.dig('phone')
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
      add_error("Veteran birth date isn't a date: #{birth_date.raw_date.inspect}") unless birth_date.valid?
    end

    # validation (header)
    def birth_date_is_in_the_past
      return unless birth_date.valid?

      add_error("Veteran birth date isn't in the past: #{birth_date.raw_date}") unless birth_date.in_the_past?
    end

    # validation
    def contestable_issue_dates_are_valid_dates
      return if contestable_issues.blank?

      contestable_issues.each_with_index do |issue, index|
        decision_date_invalid(issue, index)
        decision_date_not_in_past(issue, index)
      end
    end

    def decision_date_invalid(issue, issue_index)
      return if issue.decision_date.valid?

      add_decision_date_error "isn't a valid date: #{issue.decision_date_string.inspect}", issue_index
    end

    def decision_date_not_in_past(issue, issue_index)
      return if !issue.decision_date.valid? || issue.decision_date.in_the_past?

      add_decision_date_error "isn't in the past: #{issue.decision_date_string.inspect}", issue_index
    end

    def add_decision_date_error(string, issue_index)
      add_error "included[#{issue_index}].attributes.decisionDate #{string}"
    end

    def add_error(message)
      errors.add(:base, message)
    end

    def address_combined
      return unless veteran.dig('address', 'addressLine1')

      @address_combined ||=
        [veteran.dig('address', 'addressLine1'),
         veteran.dig('address', 'addressLine2'),
         veteran.dig('address', 'addressLine3')].compact.map(&:strip).join(' ')
    end
  end
end
