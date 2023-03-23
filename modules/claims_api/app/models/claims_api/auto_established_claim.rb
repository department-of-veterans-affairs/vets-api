# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'claims_api/special_issue_mappers/evss'
require 'claims_api/homelessness_situation_type_mapper'
require 'claims_api/homelessness_risk_situation_type_mapper'
require 'claims_api/service_branch_mapper'
require 'claims_api/claim_logger'

module ClaimsApi
  class AutoEstablishedClaim < ApplicationRecord
    include FileData
    serialize :auth_headers, JsonMarshal::Marshaller
    serialize :bgs_flash_responses, JsonMarshal::Marshaller
    serialize :bgs_special_issue_responses, JsonMarshal::Marshaller
    serialize :form_data, JsonMarshal::Marshaller
    serialize :evss_response, JsonMarshal::Marshaller
    has_kms_key
    has_encrypted :auth_headers, :bgs_flash_responses, :bgs_special_issue_responses, :evss_response, :form_data,
                  key: :kms_key, **lockbox_options

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

    def to_internal # rubocop:disable Metrics/MethodLength
      form_data['applicationExpirationDate'] ||= build_application_expiration
      form_data['claimDate'] ||= persisted? ? created_at.iso8601 : Time.zone.now.iso8601
      cast_claim_date!
      form_data['claimSubmissionSource'] = 'LH-B'
      form_data['servicePay']['separationPay']['receivedDate'] = transform_separation_pay_received_date if separation_pay_received_date? # rubocop:disable Layout/LineLength
      form_data['veteran']['changeOfAddress'] = transform_change_of_address_type_case if change_of_address_provided?
      form_data['veteran']['changeOfAddress'] = transform_change_of_address_ending_date if invalid_change_of_address_ending_date? # rubocop:disable Layout/LineLength
      form_data['disabilites'] = transform_disability_approximate_begin_dates
      form_data['disabilites'] = massage_invalid_disability_names
      form_data['disabilites'] = remove_special_issues_from_secondary_disabilities
      form_data['treatments'] = transform_treatment_dates if treatments?
      form_data['treatments'] = transform_treatment_center_names if treatments?
      form_data['serviceInformation'] = transform_service_branch
      transform_service_pay_service_branch

      resolve_special_issue_mappings!
      resolve_homelessness_situation_type_mappings!
      resolve_homelessness_risk_situation_type_mappings!
      transform_address_lines_length!

      {
        form526: form_data
      }.to_json
    end

    def self.pending?(id)
      query = where(id:)
      query.exists? && query.first.evss_id.nil? ? query.first : false
    end

    def self.evss_id_by_token(token)
      find_by(id: token)&.evss_id
    end

    def self.get_by_id_or_evss_id(id)
      if id.to_s.include?('-')
        find_by(id:)
      else
        find_by(evss_id: id)
      end
    end

    def self.get_by_id_and_icn(id, icn)
      find_by(id:, veteran_icn: icn)
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
      # previous documentation has a default example value of "OTHER", so make sure that that value is case-insensitive
      name = name.downcase if name.downcase == 'other'

      form_data['veteran']['homelessness']['currentlyHomeless']['homelessSituationType'] = mapper.code_from_name(name)

      if form_data['veteran']['homelessness']['currentlyHomeless']['otherLivingSituation'].blank?
        # Transform to meet EVSS requirements of minLength 1
        form_data['veteran']['homelessness']['currentlyHomeless']['otherLivingSituation'] = ' '
      end
    end

    def resolve_homelessness_risk_situation_type_mappings!
      return if form_data['veteran']['homelessness'].blank?
      return if form_data['veteran']['homelessness']['homelessnessRisk'].blank?

      mapper = ClaimsApi::HomelessnessRiskSituationTypeMapper.new
      name = form_data['veteran']['homelessness']['homelessnessRisk']['homelessnessRiskSituationType']
      # previous documentation has a default example value of "OTHER", so make sure that that value is case-insensitive
      name = name.downcase if name.downcase == 'other'

      form_data['veteran']['homelessness']['homelessnessRisk']['homelessnessRiskSituationType'] =
        mapper.code_from_name(name)

      if mapper.code_from_name(name) == 'OTHER' &&
         form_data['veteran']['homelessness']['homelessnessRisk']['otherLivingSituation'].blank?
        # Transform to meet EVSS requirements of minLength 1
        form_data['veteran']['homelessness']['homelessnessRisk']['otherLivingSituation'] = ' '
      end
    end

    def cast_claim_date!
      form_data['claimDate'] = DateTime.parse(form_data['claimDate']).iso8601
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

    # do not clear out 'auth_headers' or 'file_data' attributes
    # 'auth_headers' is required to make calls to EVSS for uploading docs
    # 'file_data' is required to know what doc to upload to EVSS
    # See API-14303
    def remove_encrypted_fields
      self.form_data = {} if status == ESTABLISHED
    end

    def treatments?
      form_data['treatments'].present?
    end

    def pay_type_service_branch?(category)
      form_data.dig('servicePay', category, 'payment', 'serviceBranch').present?
    end

    def transform_treatment_dates
      treatments = form_data['treatments']

      treatments.map do |treatment|
        treatment = transform_treatment_start_date(treatment:)
        treatment = transform_treatment_end_date(treatment:)
        treatment
      end
    end

    def transform_treatment_center_names
      treatments = form_data['treatments']

      treatments.map do |treatment|
        treatment['center']['name'] = ' ' if treatment.dig('center', 'name').empty?
        treatment
      end
      treatments
    end

    def transform_treatment_start_date(treatment:)
      # 'startDate' is not a required field in EVSS
      return treatment if treatment['startDate'].blank?

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
        name = truncate_disability_name(name:) if name.length > 255
        name = sanitize_disablity_name(name:, regex: invalid_characters) if name.match?(invalid_characters)
        name = strip_disablity_name(name:)
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

    def strip_disablity_name(name:)
      name.strip
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

        ClaimsApi::Logger.log('526',
                              detail: "'serviceBranch' value received is :: #{name}")
        period['serviceBranch'] = ClaimsApi::ServiceBranchMapper.new(name).value

        period
      end

      form_data['serviceInformation']['servicePeriods'] = transformed_service_periods
      form_data['serviceInformation']
    end

    # Legacy claimsApi code previously allowed servicePay-related service branch
    # values (servicePay.militaryRetiredPay.payment.serviceBranch, servicePay.separationPay.payment.serviceBranch)
    # that are not accepted by EVSS.
    # Rather than refuse those invalid values, this maps them to an equivalent value that EVSS will accept.
    # Note transform_service_branch above only handles cases found in 'serviceInformation.servicePeriod'.
    def transform_service_pay_service_branch
      %w[militaryRetiredPay separationPay].each do |pay_type|
        if pay_type_service_branch?(pay_type)
          branch = form_data['servicePay'][pay_type]['payment']['serviceBranch']
          ClaimsApi::Logger.log('526',
                                detail: "#{pay_type} 'serviceBranch' value received is :: #{branch}")

          form_data['servicePay'][pay_type]['payment']['serviceBranch'] =
            ClaimsApi::ServiceBranchMapper.new(branch).value
        end
      end
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

    def change_of_address_provided?
      form_data['veteran']['changeOfAddress'].present?
    end

    # EVSS requires that the value of 'form526.veteran.changeOfAddress.addressChangeType' be uppercase
    def transform_change_of_address_type_case
      change_of_address = form_data['veteran']['changeOfAddress']
      change_of_address_type = change_of_address['addressChangeType']
      change_of_address['addressChangeType'] = change_of_address_type.upcase

      change_of_address
    end

    def transform_address_lines_length!
      ln1 = form_data.dig('veteran', 'currentMailingAddress', 'addressLine1')
      return if ln1.nil? || (ln1.length <= 20)

      addr = form_data['veteran']['currentMailingAddress']

      ln2 = form_data.dig('veteran', 'currentMailingAddress', 'addressLine2')
      ln3 = form_data.dig('veteran', 'currentMailingAddress', 'addressLine3')
      addr['addressLine3'] = "#{ln2} #{ln3}".strip

      addr['addressLine1'] = ln1.truncate(20, omission: '', separator: /\s/)
      overflow = ln1.sub(addr['addressLine1'], '').strip

      addr['addressLine2'] = overflow

      form_data['veteran']['currentMailingAddress'] = addr
    end
  end
end
