# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'common/exceptions'

module AppealsApi
  class HigherLevelReview < ApplicationRecord
    include HlrStatus
    include PdfOutputPrep
    include ModelValidations
    required_claimant_headers %w[
      X-VA-NonVeteranClaimant-First-Name
      X-VA-NonVeteranClaimant-Last-Name
      X-VA-NonVeteranClaimant-Birth-Date
    ]

    attr_readonly :auth_headers
    attr_readonly :form_data

    scope :pii_expunge_policy, lambda {
      timeframe = 7.days.ago
      v1.where('updated_at < ? AND status IN (?)', timeframe, COMPLETE_STATUSES + ['success'])
        .or(v2.where('updated_at < ? AND status IN (?)', timeframe, COMPLETE_STATUSES))
    }

    scope :v1, lambda {
      where(api_version: 'V1')
    }

    scope :v2, lambda {
      where(api_version: 'V2')
    }

    scope :stuck_unsubmitted, lambda {
      where('created_at < ? AND status IN (?)', 2.hours.ago, %w[pending submitting])
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
    has_encrypted :auth_headers, :form_data, key: :kms_key, **lockbox_options

    NO_ADDRESS_PROVIDED_SENTENCE = 'USE ADDRESS ON FILE'
    NO_EMAIL_PROVIDED_SENTENCE = 'USE EMAIL ON FILE'
    NO_PHONE_PROVIDED_SENTENCE = 'USE PHONE ON FILE'

    # the controller applies the JSON Schemas in modules/appeals_api/config/schemas/
    # further validations:
    validate :veteran_birth_date_is_in_the_past,
             :contestable_issue_dates_are_in_the_past,
             if: proc { |a| a.form_data.present? }

    # v2 validations
    validate :claimant_birth_date_is_in_the_past,
             :required_claimant_data_is_present,
             if: proc { |a| a.api_version.upcase != 'V1' && a.form_data.present? }

    has_many :evidence_submissions, as: :supportable, dependent: :destroy
    has_many :status_updates, as: :statusable, dependent: :destroy

    def pdf_structure(pdf_version)
      Object.const_get(
        "AppealsApi::PdfConstruction::HigherLevelReview::#{pdf_version.upcase}::Structure"
      ).new(self)
    end

    # V2 Start
    def veteran
      @veteran ||= Appellant.new(
        type: :veteran,
        auth_headers:,
        form_data: data_attributes&.dig('veteran')
      )
    end

    def claimant
      @claimant ||= Appellant.new(
        type: :claimant,
        auth_headers:,
        form_data: data_attributes&.dig('claimant')
      )
    end

    def signing_appellant
      claimant.signing_appellant? ? claimant : veteran
    end

    def appellant_local_time
      signing_appellant.timezone ? created_at.in_time_zone(signing_appellant.timezone) : created_at.utc
    end

    # V2 End

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

    def veteran_birth_mm
      veteran_birth_date.strftime '%m'
    end

    def veteran_birth_dd
      veteran_birth_date.strftime '%d'
    end

    def veteran_birth_yyyy
      veteran_birth_date.strftime '%Y'
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
      veteran_data.dig('address', 'city') || ''
    end

    def state_code
      veteran_data.dig('address', 'stateCode') || ''
    end

    def country_code
      return '' unless address_combined

      veteran_data.dig('address', 'countryCodeISO2') || 'US'
    end

    def zip_code
      if zip_code_5 == '00000'
        veteran_data.dig('address', 'internationalPostalCode') || '00000'
      else
        zip_code_5
      end
    end

    def zip_code_5
      veteran_data.dig('address', 'zipCode5') || '00000'
    end

    def veteran_phone_number
      veteran_phone.to_s
    end

    def veteran_phone_data
      veteran_data&.dig('phone')
    end

    def veteran_homeless?
      form_data&.dig('data', 'attributes', 'veteran', 'homeless')
    end

    def email
      veteran.email.presence
    end

    def benefit_type
      data_attributes&.dig('benefitType').to_s.strip
    end

    def informal_conference
      data_attributes&.dig('informalConference')
    end

    def informal_conference_contact
      data_attributes&.dig('informalConferenceContact')
    end

    def informal_conference_time
      data_attributes&.dig('informalConferenceTime')
    end

    def soc_opt_in
      # This is no longer optional as of v3 of the PDF
      pdf_version&.downcase == 'v3' || data_attributes&.dig('socOptIn')
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

    def stamp_text
      "#{veteran.last_name.truncate(35)} - #{veteran.ssn.last(4)}"
    end

    # rubocop:disable Metrics/MethodLength
    def update_status(status:, code: nil, detail: nil, raise_on_error: false)
      current_status = self.status
      current_code = self.code
      current_detail = self.detail

      send(
        raise_on_error ? :update! : :update,
        status:,
        code:,
        detail:
      )

      if status != current_status || code != current_code || detail != current_detail
        AppealsApi::StatusUpdatedJob.perform_async(
          {
            status_event: 'hlr_status_updated',
            from: current_status,
            to: status.to_s,
            status_update_time: Time.zone.now.iso8601,
            statusable_id: id,
            code:,
            detail:
          }.stringify_keys
        )

        return if auth_headers.blank? # Go no further if we've removed PII

        if status == 'submitted' && email_present?
          AppealsApi::AppealReceivedJob.perform_async(
            {
              receipt_event: 'hlr_received',
              email_identifier:,
              first_name:,
              date_submitted: veterans_local_time.iso8601,
              guid: id,
              claimant_email: claimant.email,
              claimant_first_name: claimant.first_name
            }.stringify_keys
          )
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    def update_status!(status:, code: nil, detail: nil)
      update_status(status:, code:, detail:, raise_on_error: true)
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
        'veteransHealthAdministration' => 'CMP',
        'veteranReadinessAndEmployment' => 'VRE',
        'loanGuaranty' => 'CMP',
        'education' => 'EDU',
        'nationalCemeteryAdministration' => 'NCA'
      }[benefit_type]
    end

    private

    def mpi_veteran
      AppealsApi::Veteran.new(
        ssn:,
        first_name:,
        last_name:,
        birth_date: veteran_birth_date.iso8601
      )
    end

    def email_identifier
      return { id_type: 'email', id_value: email } if email.present?

      icn = mpi_veteran.mpi_icn

      return { id_type: 'ICN', id_value: icn } if icn.present?
    end

    def data_attributes
      form_data&.dig('data', 'attributes')
    end

    def veteran_data
      data_attributes&.dig('veteran')
    end

    def veteran_birth_date_string
      auth_headers['X-VA-Birth-Date']
    end

    def veteran_birth_date
      self.class.date_from_string veteran_birth_date_string
    end

    def veteran_phone
      AppealsApi::HigherLevelReview::Phone.new veteran_data&.dig('phone')
    end

    def veterans_local_time
      veterans_timezone ? created_at.in_time_zone(veterans_timezone) : created_at.utc
    end

    def veterans_timezone
      veteran_data&.dig('timezone').presence&.strip
    end

    def address_combined
      return unless veteran_data.dig('address', 'addressLine1')

      @address_combined ||=
        [veteran_data.dig('address', 'addressLine1'),
         veteran_data.dig('address', 'addressLine2'),
         veteran_data.dig('address', 'addressLine3')].compact.map(&:strip).join(' ')
    end

    def email_present?
      claimant.email.present? || email_identifier.present?
    end

    def clear_memoized_values
      @contestable_issues = @veteran = @claimant = @address_combined = nil
    end
  end
end
