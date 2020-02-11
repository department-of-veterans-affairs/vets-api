# frozen_string_literal: true

require_dependency 'claims_api/json_marshal'
require_dependency 'claims_api/concerns/file_data'

module ClaimsApi
  class AutoEstablishedClaim < ApplicationRecord
    include FileData
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)
    attr_encrypted(:evss_response, key: Settings.db_encryption_key, marshal: true, marshaler: ClaimsApi::JsonMarshal)

    has_many :supporting_documents, dependent: :destroy

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    ESTABLISHED = 'established'
    ERRORED = 'errored'
    EVSS_CLAIM_ATTRIBUTES = %i[date_filed min_est_date max_est_date open waiver_submitted
                               documents_needed development_letter_sent decision_letter_sent
                               requested_decision va_representative].freeze

    before_validation :set_md5
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
        "form526": form_data,
        "form526_uploads": [],
        "form4142": nil,
        "form0781": nil,
        "form8940": nil
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
  end
end
