# frozen_string_literal: true

require 'json_marshal/marshaller'

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
    validates :md5, uniqueness: true

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
      {
        "form526": form_data
      }.to_json
    end

    def self.pending?(id)
      query = where(id: id)
      query.exists? ? query.first : false
    end

    def self.evss_id_by_token(token)
      find_by(id: token)&.evss_id
    end

    def self.get_by_id_or_evss_id(id)
      if id.to_s.include?('-')
        find(id)
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

    def log_flashes
      Rails.logger.info("ClaimsApi: Claim[#{id}] contains the following flashes - #{flashes}") if flashes.present?
    end

    def log_special_issues
      return if special_issues.blank?

      Rails.logger.info("ClaimsApi: Claim[#{id}] contains the following special issues - #{special_issues}")
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
