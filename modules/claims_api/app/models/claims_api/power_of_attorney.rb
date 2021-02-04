# frozen_string_literal: true

require_dependency 'claims_api/stamp_signature_error'
require 'json_marshal/marshaller'
require 'common/file_helpers'

module ClaimsApi
  class PowerOfAttorney < ApplicationRecord
    include FileData
    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:source_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    PENDING = 'pending'
    UPDATED = 'updated'
    ERRORED = 'errored'

    before_validation :set_md5
    validates :md5, uniqueness: true

    def self.find_using_identifier_and_source(source_name:, id: nil, header_md5: nil, md5: nil)
      primary_identifier = {}
      primary_identifier[:id] = id if id.present?
      primary_identifier[:header_md5] = header_md5 if header_md5.present?
      primary_identifier[:md5] = md5 if md5.present?
      poa = ClaimsApi::PowerOfAttorney.find_by(primary_identifier)
      return nil if poa.present? && poa.source_data['name'] != source_name

      poa
    end

    def sign_pdf
      signatures = convert_signatures_to_images
      page_1_path = insert_signatures(1, signatures[:veteran], signatures[:representative])
      page_2_path = insert_signatures(2, signatures[:veteran], signatures[:representative])
      { page1: page_1_path, page2: page_2_path }
    end

    def convert_signatures_to_images
      {
        veteran: convert_base64_data_to_image('veteran'),
        representative: convert_base64_data_to_image('representative')
      }
    end

    def convert_base64_data_to_image(signature)
      path = "tmp/#{signature}_#{id}_signature_b64.png"

      File.open(path, 'wb') do |f|
        f.write(Base64.decode64(form_data.dig('signatures', signature)))
      end
      path
    end

    def insert_signatures(page, veteran_signature, representative_signature)
      pdf_path = Rails.root.join('modules', 'claims_api', 'config', 'pdf_templates', "21-22A-#{page}.pdf")
      stamp_path = "#{::Common::FileHelpers.random_file_path}.pdf"

      inserted = []
      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        y_representative_coords = page == 1 ? 118 : 216
        y_veteran_coords = page == 1 ? 90 : 322
        pdf.image representative_signature, at: [35, y_representative_coords], height: 20
        inserted << 'representative'
        pdf.image veteran_signature, at: [35, y_veteran_coords], height: 20
      end
      stamp(pdf_path, stamp_path, delete_source: false)
    rescue Prawn::Errors::UnsupportedImageType
      signature = inserted.empty? ? 'representative' : 'veteran'
      update signature_errors: ["#{signature} was not a recognized image format"]
      raise ClaimsApi::StampSignatureError.new(
        message: "#{signature} could not be inserted",
        detail: "#{signature} was not a recognized image format"
      )
    end

    def stamp(file_path, stamp_path, delete_source: true)
      out_path = "#{::Common::FileHelpers.random_file_path}.pdf"
      PdfFill::Filler::PDF_FORMS.stamp(file_path, stamp_path, out_path)
      File.delete(file_path) if delete_source
      out_path
    rescue
      ::Common::FileHelpers.delete_file_if_exists(out_path)
      raise
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
      source_data.present? ? source_data['icn'] : Settings.bgs.external_uid
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
      query = where(id: id)
      query.exists? ? query.first : false
    end
  end
end
