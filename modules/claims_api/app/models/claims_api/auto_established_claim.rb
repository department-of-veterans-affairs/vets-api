# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'claims_api/special_issue_mappers/evss'
require 'claims_api/homelessness_situation_type_mapper'
require 'claims_api/service_branch_mapper'

module ClaimsApi
  class AutoEstablishedClaim < ApplicationRecord
    include FileData
    serialize :auth_headers, JsonMarshal::Marshaller
    serialize :bgs_flash_responses, JsonMarshal::Marshaller
    serialize :bgs_special_issue_responses, JsonMarshal::Marshaller
    serialize :form_data, JsonMarshal::Marshaller
    serialize :evss_response, JsonMarshal::Marshaller
    has_kms_key
    encrypts :auth_headers, :bgs_flash_responses, :bgs_special_issue_responses, :evss_response, :form_data,
             key: :kms_key

    validate :validate_service_dates
    before_validation :set_md5
    after_validation :remove_encrypted_fields, on: [:update]
    after_create :log_special_issues
    after_create :log_flashes

    has_many :supporting_documents, dependent: :destroy

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    ESTABLISHED = 'established'
    ERRORED = 'errored'

    ALL_STATUSES = [PENDING, SUBMITTED, ESTABLISHED, ERRORED].freeze

    EVSS_CLAIM_ATTRIBUTES = %i[date_filed min_est_date max_est_date open waiver_submitted
                               documents_needed development_letter_sent decision_letter_sent
                               requested_decision va_representative].freeze

    validates :md5, uniqueness: true, on: :create

    EVSS_CLAIM_ATTRIBUTES.each do |attribute|
      define_method attribute do
        nil
      end
    end

    # EVSS Claims attributes with defaults
    attribute :data, default: {}
    attribute :claim_type, default: 'Compensation'
    attribute :contention_list, default: []
    attribute :events_timeline, default: []

    alias token id

    def to_internal
      form_data['applicationExpirationDate'] ||= build_application_expiration
      form_data['claimDate'] ||= (persisted? ? created_at.to_date.to_s : Time.zone.today.to_s)
      form_data['claimSubmissionSource'] = 'Lighthouse'
      form_data['bddQualified'] = bdd_qualified?
      form_data['servicePay']['separationPay']['receivedDate'] = transform_separation_pay_received_date if separation_pay_received_date? # rubocop:disable Layout/LineLength
      form_data['veteran']['changeOfAddress'] = transform_change_of_address_ending_date if invalid_change_of_address_ending_date? # rubocop:disable Layout/LineLength
      form_data['disabilites'] = transform_disability_approximate_begin_dates
      form_data['disabilites'] = massage_invalid_disability_names
      form_data['disabilites'] = remove_special_issues_from_secondary_disabilities
      form_data['treatments'] = transform_treatment_dates if treatments?
      form_data['serviceInformation'] = transform_service_branch

      resolve_special_issue_mappings!
      resolve_homelessness_situation_type_mappings!

      {
        form526: form_data
      }.to_json
    end

    def self.pending?(id)
      query = where(id: id)
      query.exists? && query.first.evss_id.nil? ? query.first : false
    end

    def self.evss_id_by_token(token)
      find_by(id: token)&.evss_id
    end

    def self.get_by_id_or_evss_id(id)
      if id.to_s.include?('-')
        find_by(id: id)
      else
        find_by(evss_id: id)
      end
    end

    def set_md5
      headers = auth_headers.except('va_eauth_authenticationauthority',
                                    'va_eauth_service_transaction_id',
                                    'va_eauth_issueinstant',
                                    'Authorization')
      self.md5 = Digest::MD5.hexdigest form_data.merge(headers).to_json
    end

    def status_from_phase(*)
      status
    end

    def uploader
      @uploader ||= ClaimsApi::SupportingDocumentUploader.new(id)
    end

    private

    EVSS_TZ = 'Central Time (US & Canada)'

    def recent_service_periods_end_dates
      end_dates = form_data.dig('serviceInformation', 'servicePeriods').map do |service_period|
        unless service_period['serviceBranch'].include?('Reserve') ||
               service_period['serviceBranch'].include?('National Guard')
          service_period['activeDutyEndDate']
        end
      end

      end_dates.compact
    end

    def user_supplied_rad_date
      end_dates = recent_service_periods_end_dates
      end_dates << form_data.dig('serviceInformation',
                                 'reservesNationalGuardService',
                                 'title10Activation',
                                 'anticipatedSeparationDate')
      end_dates.compact!
      return nil if end_dates.blank?

      end_dates.max.in_time_zone(EVSS_TZ).to_date
    end

    def days_until_release
      return 0 if user_supplied_rad_date.blank?

      form_submission_date = created_at.presence || Time.now.in_time_zone(EVSS_TZ)
      @days_until_release ||= user_supplied_rad_date - form_submission_date.to_date
    end

    def bdd_qualified?
      if days_until_release > 180
        return false if (recent_service_periods_end_dates - [user_supplied_rad_date.to_s]).any?

        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: 'User may not submit BDD more than 180 days prior to RAD date'
        )
      end

      days_until_release >= 90
    end

    def separation_pay_received_date?
      form_data.dig('servicePay', 'separationPay', 'receivedDate').present?
    end

    # EVSS requires the 'receivedDate' to be the components of an approximated date
    # We (ClaimsApi) require a date string that is then validated to be a valid date
    # Convert our validated date into the components required by EVSS
    def transform_separation_pay_received_date
      received_date = form_data.dig('servicePay', 'separationPay', 'receivedDate')
      breakout_date_components(date: received_date)
    end

    # EVSS requires the disability 'approximateBeginDate' to be the components of an approximated date
    # We (ClaimsApi) require a date string that is then validated to be a valid date
    # Convert our validated date into the components required by EVSS
    def transform_disability_approximate_begin_dates
      disabilities = form_data['disabilities']

      disabilities.map do |disability|
        next if disability['approximateBeginDate'].blank?

        disability['approximateBeginDate'] = breakout_date_components(date: disability['approximateBeginDate'])

        disability['secondaryDisabilities'] ||= []
        disability['secondaryDisabilities'].map do |secondary_disability|
          next if secondary_disability['approximateBeginDate'].blank?

          secondary_disability['approximateBeginDate'] = breakout_date_components(
            date: secondary_disability['approximateBeginDate']
          )

          secondary_disability
        end

        disability
      end
    end

    def resolve_special_issue_mappings!
      mapper = ClaimsApi::SpecialIssueMappers::Evss.new
      (form_data['disabilities'] || []).each do |disability|
        disability['specialIssues'] = (disability['specialIssues'] || []).map do |special_issue|
          mapper.code_from_name(special_issue)
        end.compact
      end
    end

    def resolve_homelessness_situation_type_mappings!
      return if form_data['veteran']['homelessness'].blank?
      return if form_data['veteran']['homelessness']['currentlyHomeless'].blank?

      mapper = ClaimsApi::HomelessnessSituationTypeMapper.new
      name = form_data['veteran']['homelessness']['currentlyHomeless']['homelessSituationType']
      form_data['veteran']['homelessness']['currentlyHomeless']['homelessSituationType'] = mapper.code_from_name(name)
    end

    def log_flashes
      Rails.logger.info("ClaimsApi: Claim[#{id}] contains the following flashes - #{flashes}") if flashes.present?
    end

    def log_special_issues
      return if special_issues.blank?

      Rails.logger.info("ClaimsApi: Claim[#{id}] contains the following special issues - #{special_issues}")
    end

    def validate_service_dates
      service_periods = form_data.dig('serviceInformation', 'servicePeriods')

      service_periods.each do |service_period|
        start_date = Date.parse(service_period['activeDutyBeginDate']) if service_period['activeDutyBeginDate'].present?
        end_date = Date.parse(service_period['activeDutyEndDate']) if service_period['activeDutyEndDate'].present?

        if start_date.present? && end_date.blank?
          next
        elsif start_date.blank?
          errors.add :activeDutyBeginDate, 'must be present'
        elsif (start_date.blank? && end_date.present?) || start_date > end_date
          errors.add :activeDutyBeginDate, 'must be before activeDutyEndDate'
        end
      end
    end

    def remove_encrypted_fields
      if status == ESTABLISHED
        self.form_data = {}
        self.auth_headers = {}
        self.file_data = nil
      end
    end

    def treatments?
      form_data['treatments'].present?
    end

    def transform_treatment_dates
      treatments = form_data['treatments']

      treatments.map do |treatment|
        treatment = transform_treatment_start_date(treatment: treatment)
        treatment = transform_treatment_end_date(treatment: treatment)
        treatment
      end
    end

    def transform_treatment_start_date(treatment:)
      start_date = treatment['startDate']
      treatment['startDate'] = breakout_date_components(date: start_date)
      treatment
    end

    def transform_treatment_end_date(treatment:)
      # 'endDate' is not a required field in EVSS
      return treatment if treatment['endDate'].blank?

      end_date = treatment['endDate']
      treatment['endDate'] = breakout_date_components(date: end_date)
      treatment
    end

    def breakout_date_components(date:)
      temp = Date.parse(date)

      {
        'year': temp.year.to_s,
        'month': temp.month.to_s,
        'day': temp.day.to_s
      }
    end

    def build_application_expiration
      (Time.zone.now.to_date + 1.year).to_s
    end

    # EVSS requires disability names to be less than 255 characters and cannot contain special characters.
    # Rather than raise an exception to the user, massage the name into a valid state that EVSS will accept.
    def massage_invalid_disability_names
      disabilities = form_data['disabilities']
      invalid_characters = %r{[^a-zA-Z0-9\\\-'.,/() ]}

      disabilities.map do |disability|
        name = disability['name']
        name = truncate_disability_name(name: name) if name.length > 255
        name = sanitize_disablity_name(name: name, regex: invalid_characters) if name.match?(invalid_characters)
        disability['name'] = name

        disability
      end
    end

    def truncate_disability_name(name:)
      name.truncate(255, omission: '')
    end

    def sanitize_disablity_name(name:, regex:)
      name.gsub(regex, '')
    end

    def invalid_change_of_address_ending_date?
      change_of_address = form_data['veteran']['changeOfAddress']

      return false if change_of_address.blank?
      return true if temporary_change_of_address_missing_ending_date?
      return true if permanent_change_of_address_includes_ending_date?

      false
    end

    def temporary_change_of_address_missing_ending_date?
      change_of_address = form_data['veteran']['changeOfAddress']

      return false if change_of_address.blank?

      change_of_address['addressChangeType'].casecmp?('TEMPORARY') && change_of_address['endingDate'].blank?
    end

    def permanent_change_of_address_includes_ending_date?
      change_of_address = form_data['veteran']['changeOfAddress']

      return false if change_of_address.blank?

      change_of_address['addressChangeType'].casecmp?('PERMANENT') && change_of_address['endingDate'].present?
    end

    # EVSS requires a 'TEMPORARY' 'changeOfAddress' to include an 'endingDate'
    # EVSS requires a 'PERMANENT' 'changeOfAddress' to NOT include an 'endingDate'
    # If the submission is in an invalid state, let's try to gracefully fix it for them
    def transform_change_of_address_ending_date
      change_of_address = form_data['veteran']['changeOfAddress']
      change_of_address = add_change_of_address_ending_date if temporary_change_of_address_missing_ending_date?
      change_of_address = remove_change_of_address_ending_date if permanent_change_of_address_includes_ending_date?

      change_of_address
    end

    def add_change_of_address_ending_date
      change_of_address = form_data['veteran']['changeOfAddress']
      change_of_address['endingDate'] = (Time.zone.now.to_date + 1.year).to_s
      change_of_address
    end

    def remove_change_of_address_ending_date
      change_of_address = form_data['veteran']['changeOfAddress']
      change_of_address.delete('endingDate')
      change_of_address
    end

    # For whatever reason, legacy ClaimsApi code previously allowed
    # 'serviceInformation.servicePeriod.serviceBranch' values that are not accepted by EVSS.
    # Rather than refuse those invalid values, this maps them to an equivalent value that EVSS will accept.
    def transform_service_branch
      received_service_periods = form_data['serviceInformation']['servicePeriods']

      transformed_service_periods = received_service_periods.map do |period|
        name = period['serviceBranch']
        period['serviceBranch'] = ClaimsApi::ServiceBranchMapper.new(name).value

        period
      end

      form_data['serviceInformation']['servicePeriods'] = transformed_service_periods
      form_data['serviceInformation']
    end

    # The legacy ClaimsApi code has always allowed 'secondaryDisabilities' to have 'specialIssues'.
    # EVSS does not allow this.
    # Rather than break the API by removing 'specialIssues' from the 'secondaryDisabilities' schema,
    # just detect the invalid case and remove the 'specialIssues' before sending to EVSS.
    def remove_special_issues_from_secondary_disabilities
      disabilities = form_data['disabilites']

      disabilities.map do |disability|
        next if disability['secondaryDisabilities'].blank?

        disability['secondaryDisabilities'].map do |secondary|
          secondary.delete('specialIssues') if secondary['specialIssues'].present?

          secondary
        end
      end
    end
  end
end
