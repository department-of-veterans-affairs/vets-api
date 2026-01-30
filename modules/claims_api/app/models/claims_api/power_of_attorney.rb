# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'common/file_helpers'

module ClaimsApi
  class PowerOfAttorney < ApplicationRecord
    include FileData
    serialize :auth_headers, coder: JsonMarshal::Marshaller
    serialize :form_data, coder: JsonMarshal::Marshaller
    serialize :source_data, coder: JsonMarshal::Marshaller
    has_kms_key
    has_encrypted :auth_headers, :form_data, :source_data, key: :kms_key, **lockbox_options

    has_many :processes, as: :processable, dependent: :destroy
    has_one :power_of_attorney_request, dependent: :nullify

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    UPLOADED = 'uploaded'
    UPDATED = 'updated'
    ERRORED = 'errored'

    ALL_STATUSES = [PENDING, SUBMITTED, UPLOADED, UPDATED, ERRORED].freeze

    before_save :set_header_hash

    def self.find_using_identifier_and_source(primary_identifier, source_name)
      # md5 deprecated 3/26/2025 due to security: https://github.com/department-of-veterans-affairs/vets-api/security/code-scanning/852
      # it's possible to have duplicate POAs, so be sure to return the most recently created match
      poas = ClaimsApi::PowerOfAttorney.where(primary_identifier).order(created_at: :desc)
      poas = poas.select { |poa| poa.source_data['name'] == source_name }
      return nil if poas.blank?

      poas.last
    end

    def fetch_file_path(uploader)
      if Settings.evss.s3.uploads_enabled
        temp = URI.parse(uploader.file.url).open
        temp.path
      else
        uploader.file.file
      end
    end

    def date_request_accepted
      created_at&.to_date.to_s
    end

    def representative
      form_data
    end

    def previous_poa
      current_poa
    end

    def set_header_hash
      headers = auth_headers.except('va_eauth_authenticationauthority',
                                    'va_eauth_service_transaction_id',
                                    'va_eauth_issueinstant',
                                    'Authorization')
      headers['status'] = status
      self.header_hash = Digest::SHA256.hexdigest headers.to_json
    end

    def processes
      @processes ||= ClaimsApi::Process.where(processable: self)
                                       .in_order_of(:step_type, ClaimsApi::Process::VALID_POA_STEP_TYPES).to_a
    end

    def steps
      ClaimsApi::Process::VALID_POA_STEP_TYPES.each do |step_type|
        unless processes.any? { |p| p.step_type == step_type }
          index = ClaimsApi::Process::VALID_POA_STEP_TYPES.index(step_type)
          processes.insert(index, ClaimsApi::Process.new(step_type:, step_status: 'NOT_STARTED', processable: self))
        end
      end

      processes.map do |p|
        {
          type: p.step_type,
          status: p.step_status,
          completed_at: p.completed_at,
          next_step: p.next_step
        }
      end
    end

    def process_errors
      processes.map do |p|
        error_message = p.error_messages.last
        next unless error_message

        {
          title: error_message['title'],
          detail: error_message['detail'],
          code: p.step_type
        }
      end.compact
    end

    def uploader
      @uploader ||= ClaimsApi::PowerOfAttorneyUploader.new(id)
    end

    def external_key
      source_data.present? ? source_data['email'] : Settings.bgs.external_key
    end

    def external_uid
      return source_data['icn'] if source_data.present? && source_data['icn'].present?

      Settings.bgs.external_uid
    end

    def signature_image_paths
      @signature_image_paths ||= {}
    end

    def create_signature_image(signature_type)
      path = "/tmp/#{signature_type}_#{id}_signature.png"
      File.binwrite(path, Base64.decode64(form_data.dig('signatures', signature_type)))
      signature_image_paths[signature_type] = path
    end

    def self.pending?(id)
      query = where(id:)
      query.exists? ? query.first : false
    end
  end
end
