# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'common/file_helpers'

module ClaimsApi
  class PowerOfAttorney < ApplicationRecord
    include FileData
    serialize :auth_headers, JsonMarshal::Marshaller
    serialize :form_data, JsonMarshal::Marshaller
    serialize :source_data, JsonMarshal::Marshaller
    has_kms_key
    has_encrypted :auth_headers, :form_data, :source_data, key: :kms_key, **lockbox_options

    PENDING = 'pending'
    SUBMITTED = 'submitted'
    UPLOADED = 'uploaded'
    UPDATED = 'updated'
    ERRORED = 'errored'

    ALL_STATUSES = [PENDING, SUBMITTED, UPLOADED, UPDATED, ERRORED].freeze

    before_save :set_md5

    def self.find_using_identifier_and_source(source_name:, id: nil, header_md5: nil, md5: nil)
      primary_identifier = {}
      primary_identifier[:id] = id if id.present?
      primary_identifier[:header_md5] = header_md5 if header_md5.present?
      primary_identifier[:md5] = md5 if md5.present?
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

    def set_md5
      headers = auth_headers.except('va_eauth_authenticationauthority',
                                    'va_eauth_service_transaction_id',
                                    'va_eauth_issueinstant',
                                    'Authorization')
      headers['status'] = status
      self.header_md5 = Digest::MD5.hexdigest headers.to_json
      self.md5 = Digest::MD5.hexdigest form_data.merge(headers).to_json
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
      File.open(path, 'wb') do |f|
        f.write(Base64.decode64(form_data.dig('signatures', signature_type)))
      end
      signature_image_paths[signature_type] = path
    end

    def self.pending?(id)
      query = where(id:)
      query.exists? ? query.first : false
    end
  end
end
