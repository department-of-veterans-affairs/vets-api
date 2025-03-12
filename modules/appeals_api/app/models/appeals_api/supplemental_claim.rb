# frozen_string_literal: true

require 'json_marshal/marshaller'

module AppealsApi
  class SupplementalClaim < ApplicationRecord
    include AppealScopes
    include ScStatus
    include PdfOutputPrep
    include ModelValidations

    required_claimant_headers %w[X-VA-NonVeteranClaimant-First-Name X-VA-NonVeteranClaimant-Last-Name]

    attr_readonly :auth_headers
    attr_readonly :form_data

    before_create :assign_metadata, :assign_veteran_icn
    before_update :submit_evidence_to_central_mail!, if: -> { status_changed_to_complete? && delay_evidence_enabled? }

    def self.past?(date)
      date < Time.zone.today
    end

    def self.date_from_string(string)
      string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
    rescue ArgumentError
      nil
    end

    scope :stuck_unsubmitted, lambda {
      where('created_at < ? AND status IN (?)', 2.hours.ago, %w[pending submitting])
    }

    scope :v2, -> { where(api_version: 'V2') }
    scope :v0, -> { where(api_version: 'V0') }

    serialize :auth_headers, coder: JsonMarshal::Marshaller
    serialize :form_data, coder: JsonMarshal::Marshaller
    has_kms_key
    has_encrypted :auth_headers, :form_data, key: :kms_key, **lockbox_options

    has_many :evidence_submissions, as: :supportable, dependent: :destroy
    has_many :status_updates, as: :statusable, dependent: :destroy

    # the controller applies the JSON Schemas in modules/appeals_api/config/schemas/
    # further validations:
    validate(
      :veteran_birth_date_is_in_the_past,
      :required_claimant_data_is_present,
      :validate_claimant_type,
      :contestable_issue_dates_are_in_the_past,
      :validate_retrieve_from_date_range,
      :claimant_birth_date_is_in_the_past,
      :country_codes_valid,
      if: proc { |a| a.form_data.present? }
    )

    def pdf_structure(pdf_version)
      Object.const_get(
        "AppealsApi::PdfConstruction::SupplementalClaim::#{pdf_version.upcase}::Structure"
      ).new(self)
    end

    def assign_metadata
      return unless %w[v2 v0].include?(api_version&.downcase)

      self.metadata = {
        central_mail_business_line: lob,
        form_data: { benefit_type:, evidence_type: },
        non_veteran_claimant: non_veteran_claimant?,
        potential_write_in_issue_count: contestable_issues.filter do |issue|
          issue['attributes']['ratingIssueReferenceId'].blank?
        end.count
      }
    end

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

    def homeless_poc
      @homeless_point_of_contact_phone ||= Appellant.new(
        type: nil,
        auth_headers: nil,
        form_data: { 'phone' => data_attributes&.dig('homelessPointOfContactPhone') }
      )
    end

    def homeless
      data_attributes&.dig('homeless')
    end

    def homeless_living_situation
      data_attributes&.dig('homelessLivingSituation')
    end

    def homeless_other_reason
      data_attributes&.dig('homelessLivingSituationOther')
    end

    def homeless_point_of_contact
      data_attributes&.dig('homelessPointOfContact')
    end

    def treatment_locations
      evidence_submission&.dig('treatmentLocations')
    end

    def treatment_location_other_details
      evidence_submission&.dig('treatmentLocationOther')
    end

    def non_veteran_claimant?
      claimant.signing_appellant?
    end

    def signing_appellant
      non_veteran_claimant? ? claimant : veteran
    end

    def appellant_local_time
      signing_appellant.timezone ? created_at.in_time_zone(signing_appellant.timezone) : created_at.utc
    end

    def full_name
      first_name = signing_appellant.first_name
      middle_initial = signing_appellant.middle_initial
      last_name = signing_appellant.last_name

      "#{first_name} #{middle_initial} #{last_name}".squeeze(' ').strip
    end

    def veteran_dob_month
      veteran.birth_date.strftime '%m'
    end

    def veteran_dob_day
      veteran.birth_date.strftime '%d'
    end

    def veteran_dob_year
      veteran.birth_date.strftime '%Y'
    end

    def signing_appellant_zip_code
      signing_appellant.zip_code_5 || '00000'
    end

    def veteran_zip_code
      veteran.zip_code_5 || '00000'
    end

    def consumer_name
      auth_headers['X-Consumer-Username']
    end

    def consumer_id
      auth_headers['X-Consumer-ID']
    end

    def benefit_type
      data_attributes['benefitType']&.strip
    end

    def mst_disclosure
      data_attributes['mstUpcomingEventDisclosure']&.strip
    end

    def claimant_type
      data_attributes['claimantType']&.strip
    end

    def claimant_type_other_text
      data_attributes['claimantTypeOtherValue']&.strip
    end

    def alternate_signer_first_name
      (auth_headers&.dig('X-Alternate-Signer-First-Name') || \
        form_data&.dig('data', 'attributes', 'alternateSigner', 'firstName'))&.strip
    end

    def alternate_signer_middle_initial
      (auth_headers&.dig('X-Alternate-Signer-Middle-Initial') || \
        form_data&.dig('data', 'attributes', 'alternateSigner', 'middleInitial'))&.strip
    end

    def alternate_signer_last_name
      (auth_headers&.dig('X-Alternate-Signer-Last-Name') || \
        form_data&.dig('data', 'attributes', 'alternateSigner', 'lastName'))&.strip
    end

    def alternate_signer_full_name
      first_name = alternate_signer_first_name
      middle_initial = alternate_signer_middle_initial
      last_name = alternate_signer_last_name

      "#{first_name} #{middle_initial} #{last_name}".squeeze(' ').strip
    end

    def contestable_issues
      issues = form_data['included'] || []

      @contestable_issues ||= issues.map do |issue|
        AppealsApi::ContestableIssue.new(issue)
      end
    end

    def evidence_submission_days_window
      7
    end

    def accepts_evidence?
      true
    end

    def outside_submission_window_error
      {
        title: 'unprocessable_entity',
        detail: I18n.t('appeals_api.errors.sc_outside_submission_window'),
        code: 'OutsideSubmissionWindow',
        status: '422'
      }
    end

    def soc_opt_in
      # This was removed from the form in PDF version v3 - it is no longer optional.
      # - In Decision Reviews APIs, it can only be false if the pdf version is older than v3
      # - In the Supplemental Claims API v0, it is no longer part of the schema
      pdf_version&.downcase == 'v3' || api_version&.downcase == 'v0' || data_attributes&.dig('socOptIn')
    end

    def new_evidence
      evidence_submissions = evidence_submission['retrieveFrom'] || []

      evidence_submissions.map do |evidence|
        ScEvidence.new(evidence['type'], evidence['attributes'])
      end
    end

    def form_5103_notice_acknowledged
      data_attributes['form5103Acknowledged']
    end

    def date_signed
      appellant_local_time.strftime('%m/%d/%Y')
    end

    def stamp_text
      "#{veteran.last_name.truncate(35)} - #{veteran.ssn.last(4)}"
    end

    def evidence_type
      evidence_submission&.dig('evidenceType')
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
            status_event: 'sc_status_updated',
            from: current_status,
            to: status.to_s,
            status_update_time: Time.zone.now.iso8601,
            statusable_id: id,
            code:,
            detail:
          }.deep_stringify_keys
        )

        return if auth_headers.blank? # Go no further if we've removed PII

        if status == 'submitted' && email_present?
          AppealsApi::AppealReceivedJob.perform_async(id, self.class.name, appellant_local_time.iso8601)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    def update_status!(status:, code: nil, detail: nil)
      update_status(status:, code:, detail:, raise_on_error: true)
    end

    def submit_evidence_to_central_mail!
      evidence_submissions&.each(&:submit_to_central_mail!)
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

    def email_identifier
      return { id_type: 'email', id_value: signing_appellant.email } if signing_appellant.email.present?

      icn = mpi_veteran.mpi_icn

      icn.present? ? { id_type: 'ICN', id_value: icn } : {}
    end

    private

    #  Must supply non-veteran claimantType if claimant fields present
    def validate_claimant_type
      return unless claimant_type == 'veteran' && signing_appellant.claimant?

      source = '/data/attributes/claimantType'

      errors.add source, I18n.t('appeals_api.errors.sc_incorrect_claimant_type')
    end

    def mpi_veteran
      AppealsApi::Veteran.new(
        ssn: veteran.ssn,
        first_name: veteran.first_name,
        last_name: veteran.last_name,
        birth_date: veteran.birth_date.iso8601
      )
    end

    def data_attributes
      form_data&.dig('data', 'attributes')
    end

    def evidence_submission
      data_attributes&.dig('evidenceSubmission')
    end

    # Used in shared model validations
    def veteran_birth_date
      veteran.birth_date
    end

    def email_present?
      claimant.email.present? || email_identifier.present?
    end

    def status_changed_to_complete?
      status_changed? && status == 'complete'
    end

    def delay_evidence_enabled?
      Flipper.enabled?(:decision_review_delay_evidence)
    end

    def clear_memoized_values
      @contestable_issues = @veteran = @claimant = nil
    end

    def assign_veteran_icn
      # Ensure veteran_icn is set - this value will be retained after the PII is deleted
      if veteran_icn.blank?
        self.veteran_icn = if (header_icn = auth_headers['X-VA-ICN'].presence)
                             # Decision Reviews API
                             header_icn
                           else
                             # Supplemental Claims API v0
                             form_data.dig('data', 'attributes', 'veteran', 'icn').presence
                           end
      end
    end
  end
end
