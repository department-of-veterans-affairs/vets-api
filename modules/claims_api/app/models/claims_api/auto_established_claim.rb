# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'claims_api/special_issue_mappers/evss'
require 'claims_api/homelessness_situation_type_mapper'

module ClaimsApi
  class AutoEstablishedClaim < ApplicationRecord
    include FileData
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:evss_response, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:bgs_flash_responses, key: Settings.db_encryption_key,
                                         marshal: true,
                                         marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:bgs_special_issue_responses, key: Settings.db_encryption_key,
                                                 marshal: true,
                                                 marshaler: JsonMarshal::Marshaller)

    validate :validate_service_dates
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

    before_validation :set_md5
    after_validation :remove_encrypted_fields, on: [:update]
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
      form_data['claimDate'] ||= (persisted? ? created_at.to_date.to_s : Time.zone.today.to_s)
      form_data['claimSubmissionSource'] = 'Lighthouse'
      form_data['bddQualified'] = bdd_qualified?
      if separation_pay_received_date?
        form_data['servicePay']['separationPay']['receivedDate'] = breakout_separation_pay_received_date
      end

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

    def breakout_separation_pay_received_date
      received_date = form_data.dig('servicePay', 'separationPay', 'receivedDate')

      temp = Date.parse(received_date)

      {
        'year': temp.year.to_s,
        'month': temp.month.to_s,
        'day': temp.day.to_s
      }
    end

    def resolve_special_issue_mappings!
      mapper = ClaimsApi::SpecialIssueMappers::Evss.new
      (form_data['disabilities'] || []).each do |disability|
        disability['specialIssues'] = (disability['specialIssues'] || []).map do |special_issue|
          mapper.code_from_name(special_issue)
        end.compact

        (disability['secondaryDisabilities'] || []).each do |secondary_disability|
          secondary_disability['specialIssues'] = (secondary_disability['specialIssues'] || []).map do |special_issue|
            mapper.code_from_name(special_issue)
          end.compact
        end
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
  end
end
