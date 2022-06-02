# frozen_string_literal: true

require 'json_marshal/marshaller'
# require 'common/exceptions'

module AppealsApi
  class SupplementalClaim < ApplicationRecord
    include ScStatus
    include PdfOutputPrep

    attr_readonly :auth_headers
    attr_readonly :form_data

    def self.past?(date)
      date < Time.zone.today
    end

    def self.date_from_string(string)
      string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
    rescue ArgumentError
      nil
    end

    scope :pii_expunge_policy, lambda {
      where('updated_at < ? AND status IN (?)', 7.days.ago, COMPLETE_STATUSES)
    }

    serialize :auth_headers, JsonMarshal::Marshaller
    serialize :form_data, JsonMarshal::Marshaller
    has_kms_key
    encrypts :auth_headers, :form_data, key: :kms_key, **lockbox_options

    has_many :evidence_submissions, as: :supportable, dependent: :destroy
    has_many :status_updates, as: :statusable, dependent: :destroy
    # the controller applies the JSON Schemas in modules/appeals_api/config/schemas/
    # further validations:
    validate(
      :birth_date_is_in_the_past,
      :required_claimant_data_is_present,
      :contestable_issue_dates_are_valid_dates,
      if: proc { |a| a.form_data.present? }
    )

    def pdf_structure(version)
      Object.const_get(
        "AppealsApi::PdfConstruction::SupplementalClaim::#{version.upcase}::Structure"
      ).new(self)
    end

    def veteran
      @veteran ||= Appellant.new(
        type: :veteran,
        auth_headers: auth_headers,
        form_data: data_attributes&.dig('veteran')
      )
    end

    def claimant
      @claimant ||= Appellant.new(
        type: :claimant,
        auth_headers: auth_headers,
        form_data: data_attributes&.dig('claimant')
      )
    end

    def signing_appellant
      claimant.signing_appellant? ? claimant : veteran
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

    def consumer_name
      auth_headers['X-Consumer-Username']
    end

    def consumer_id
      auth_headers['X-Consumer-ID']
    end

    def benefit_type
      data_attributes['benefitType']&.strip
    end

    def claimant_type
      data_attributes['claimantType']&.strip
    end

    def claimant_type_other_text
      data_attributes['claimantTypeOtherValue']&.strip
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
      data_attributes['socOptIn']
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

    def update_status!(status:, code: nil, detail: nil)
      current_status = self.status
      update!(status: status, code: code, detail: detail)

      update_handler = Events::Handler.new(event_type: :sc_status_updated, opts: {
                                             from: current_status,
                                             to: status.to_s,
                                             status_update_time: Time.zone.now.iso8601,
                                             statusable_id: id
                                           })
      update_handler.handle! unless status == current_status

      # Go no further if we've removed PII
      return if auth_headers.blank?

      email_handler = Events::Handler.new(event_type: :sc_received, opts: {
                                            email_identifier: email_identifier,
                                            first_name: veteran.first_name,
                                            date_submitted: appellant_local_time.iso8601,
                                            guid: id,
                                            claimant_email: claimant&.email,
                                            claimant_first_name: claimant&.first_name
                                          })
      email_handler.handle! if status == 'submitted' && (claimant&.email&.present? || email_identifier.present?)
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
        'nationalCemeteryAdministration' => 'CMP'
      }[benefit_type]
    end

    private

    def mpi_veteran
      AppealsApi::Veteran.new(
        ssn: veteran.ssn,
        first_name: veteran.first_name,
        last_name: veteran.last_name,
        birth_date: veteran.birth_date.iso8601
      )
    end

    def email_identifier
      return { id_type: 'email', id_value: signing_appellant.email } if signing_appellant.email.present?

      icn = mpi_veteran.mpi_icn

      return { id_type: 'ICN', id_value: icn } if icn.present?
    end

    def data_attributes
      form_data&.dig('data', 'attributes')
    end

    def evidence_submission
      data_attributes['evidenceSubmission']
    end

    # validation (header)
    def birth_date_is_in_the_past
      return unless veteran.birth_date

      unless self.class.past? veteran.birth_date
        add_error("Veteran birth date isn't in the past: #{veteran.birth_date}")
      end
    end

    # validation (header & body)
    # Schemas take care of most of the requirements, but we need to check that both header & body data is provided
    def required_claimant_data_is_present
      has_claimant_headers = claimant.first_name.present?
      # form data that includes a claimant is also sufficient to know it's passed the schema
      has_claimant_data = data_attributes&.fetch('claimant', nil).present?

      return if !has_claimant_headers && !has_claimant_data # No claimant headers or data? not a problem!
      return if has_claimant_headers && has_claimant_data # Has both claimant headers and data? A-ok!

      add_error('Claimant data was provided but missing claimant headers') unless has_claimant_headers
      add_error('Claimant headers were provided but missing claimant data') unless has_claimant_data
    end

    def contestable_issue_dates_are_valid_dates
      return if contestable_issues.blank?

      contestable_issues.each_with_index do |issue, index|
        decision_date_not_in_past(issue, index)
      end
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

    def clear_memoized_values
      @contestable_issues = @veteran = @claimant = nil
    end
  end
end
