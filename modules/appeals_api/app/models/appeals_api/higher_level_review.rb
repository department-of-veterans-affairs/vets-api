# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'common/exceptions'

module AppealsApi
  class HigherLevelReview < ApplicationRecord
    include HlrStatus

    scope :pii_expunge_policy, lambda {
      where('updated_at < ? AND status IN (?)', 7.days.ago, COMPLETE_STATUSES)
    }

    def self.past?(date)
      date < Time.zone.today
    end

    def self.date_from_string(string)
      string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
    rescue ArgumentError
      nil
    end

    serialize :auth_headers, JsonMarshal::Marshaller
    serialize :form_data, JsonMarshal::Marshaller
    has_kms_key
    encrypts :auth_headers, :form_data, key: :kms_key

    NO_ADDRESS_PROVIDED_SENTENCE = 'USE ADDRESS ON FILE'
    NO_EMAIL_PROVIDED_SENTENCE = 'USE EMAIL ON FILE'
    NO_PHONE_PROVIDED_SENTENCE = 'USE PHONE ON FILE'

    # the controller applies the JSON Schemas in modules/appeals_api/config/schemas/
    # further validations:
    validate(
      :birth_date_is_a_date,
      :birth_date_is_in_the_past,
      :contestable_issue_dates_are_valid_dates,
      if: proc { |a| a.form_data.present? }
    )

    has_many :evidence_submissions, as: :supportable, dependent: :destroy
    has_many :status_updates, as: :statusable, dependent: :destroy

    def pdf_structure(version)
      Object.const_get(
        "AppealsApi::PdfConstruction::HigherLevelReview::#{version.upcase}::Structure"
      ).new(self)
    end

    def claimant
      return unless auth_headers['X-VA-Claimant-First-Name'] && auth_headers['X-VA-Claimant-Last-Name']

      NonVeteranClaimant.new(auth_headers: auth_headers, form_data: data_attributes&.dig('claimant'))
    end

    def first_name
      auth_headers['X-VA-First-Name']
    end

    def middle_initial
      auth_headers['X-VA-Middle-Initial']
    end

    def last_name
      auth_headers['X-VA-Last-Name']
    end

    def full_name
      "#{first_name} #{middle_initial} #{last_name}".squeeze(' ').strip
    end

    def ssn
      auth_headers['X-VA-SSN']
    end

    def file_number
      auth_headers['X-VA-File-Number']
    end

    def birth_mm
      birth_date.strftime '%m'
    end

    def birth_dd
      birth_date.strftime '%d'
    end

    def birth_yyyy
      birth_date.strftime '%Y'
    end

    def service_number
      auth_headers['X-VA-Service-Number']
    end

    def insurance_policy_number
      auth_headers['X-VA-Insurance-Policy-Number']
    end

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

    def zip_code
      if zip_code_5 == '00000'
        veteran.dig('address', 'internationalPostalCode') || '00000'
      else
        zip_code_5
      end
    end

    def zip_code_5
      veteran.dig('address', 'zipCode5') || '00000'
    end

    def veteran_phone_number
      veteran_phone.to_s
    end

    def veteran_phone_data
      veteran&.dig('phone')
    end

    def veteran_homeless?
      form_data&.dig('data', 'attributes', 'veteran', 'homeless')
    end

    def email
      veteran&.dig('emailAddressText').to_s.strip
    end

    def email_v2
      veteran&.dig('email').to_s.strip
    end

    def benefit_type
      data_attributes&.dig('benefitType').to_s.strip
    end

    def same_office
      data_attributes&.dig('sameOffice')
    end

    def informal_conference
      data_attributes&.dig('informalConference')
    end

    def informal_conference_times
      data_attributes&.dig('informalConferenceTimes') || []
    end

    def informal_conference_contact
      data_attributes&.dig('informalConferenceContact')
    end

    # V2 only allows one choice of conference time
    def informal_conference_time
      data_attributes&.dig('informalConferenceTime')
    end

    def soc_opt_in
      data_attributes&.dig('socOptIn')
    end

    def contestable_issues
      issues = form_data['included'] || []

      @contestable_issues ||= issues.map do |issue|
        AppealsApi::ContestableIssue.new(issue)
      end
    end

    def date_signed
      veterans_local_time.strftime('%m/%d/%Y')
    end

    def date_signed_mm
      veterans_local_time.strftime '%m'
    end

    def date_signed_dd
      veterans_local_time.strftime '%d'
    end

    def date_signed_yyyy
      veterans_local_time.strftime '%Y'
    end

    def consumer_name
      auth_headers&.dig('X-Consumer-Username')
    end

    def consumer_id
      auth_headers&.dig('X-Consumer-ID')
    end

    def update_status!(status:, code: nil, detail: nil)
      update_handler = Events::Handler.new(event_type: :hlr_status_updated, opts: {
                                             from: self.status,
                                             to: status,
                                             status_update_time: Time.zone.now.iso8601,
                                             statusable_id: id
                                           })

      email_handler = Events::Handler.new(event_type: :hlr_received, opts: {
                                            email_identifier: email_identifier,
                                            first_name: first_name,
                                            date_submitted: veterans_local_time.iso8601,
                                            guid: id
                                          })

      update!(status: status, code: code, detail: detail)

      update_handler.handle!
      email_handler.handle! if status == 'submitted' && email_identifier.present?
    end

    def informal_conference_rep
      data_attributes&.dig('informalConferenceRep')
    end

    def informal_conference_rep_phone
      AppealsApi::HigherLevelReview::Phone.new informal_conference_rep&.dig('phone')
    end

    def lob
      {
        'compensation' => 'CMP',
        'pensionSurvivorsBenefits' => 'PMC',
        'fiduciary' => 'FID',
        'lifeInsurance' => 'INS',
        'veteransHealthAdministration' => 'OTH',
        'veteranReadinessAndEmployment' => 'VRE',
        'loanGuaranty' => 'OTH',
        'education' => 'EDU',
        'nationalCemeteryAdministration' => 'OTH'
      }[benefit_type]
    end

    private

    def mpi_veteran
      AppealsApi::Veteran.new(
        ssn: ssn,
        first_name: first_name,
        last_name: last_name,
        birth_date: birth_date.iso8601
      )
    end

    def email_identifier
      return { id_type: 'email', id_value: email } if email.present?
      return { id_type: 'email', id_value: email_v2 } if email_v2.present?

      icn = mpi_veteran.mpi_icn

      return { id_type: 'ICN', id_value: icn } if icn.present?
    end

    def data_attributes
      form_data&.dig('data', 'attributes')
    end

    def veteran
      data_attributes&.dig('veteran')
    end

    def birth_date_string
      auth_headers['X-VA-Birth-Date']
    end

    def birth_date
      self.class.date_from_string birth_date_string
    end

    def veteran_phone
      AppealsApi::HigherLevelReview::Phone.new veteran&.dig('phone')
    end

    def veterans_local_time
      veterans_timezone ? created_at.in_time_zone(veterans_timezone) : created_at.utc
    end

    def veterans_timezone
      veteran&.dig('timezone').presence&.strip
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

    def contestable_issue_dates_are_valid_dates
      return if contestable_issues.blank?

      contestable_issues.each_with_index do |issue, index|
        decision_date_invalid(issue, index)
        decision_date_not_in_past(issue, index)
      end
    end

    def decision_date_invalid(issue, issue_index)
      return if issue.decision_date

      add_decision_date_error "isn't a valid date: #{issue.decision_date_string.inspect}", issue_index
    end

    def decision_date_not_in_past(issue, issue_index)
      return if issue.decision_date.nil? || issue.decision_date_past?

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
