# frozen_string_literal: true

require_dependency 'claims_api/concerns/file_data'

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

    def sign_pdf
      signature = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'signature.png')
      insert_signatures(signature, signature)
    end

    def convert_base64_data_to_image
      signature = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'signature_b64.txt')
      signature_file = File.read(signature)
      File.open('tmp/signature_b64.png', 'wb') do |f|
        f.write(Base64.decode64(signature_file))
      end
    end

    def insert_signatures(veteran_signature, representative_signature)
      pdf_path = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '21-22A-1.pdf')
      stamp_path = Common::FileHelpers.random_file_path
      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        pdf.image representative_signature, at: [35, 118], height: 20
        pdf.image veteran_signature, at: [35, 90], height: 20
      end
      `open #{stamp(pdf_path, stamp_path)}`
    end

    def stamp(file_path, stamp_path)
      out_path = "#{Common::FileHelpers.random_file_path}.pdf"
      PdfFill::Filler::PDF_FORMS.stamp(file_path, stamp_path, out_path)
      File.delete(file_path)
      out_path
    rescue
      Common::FileHelpers.delete_file_if_exists(out_path)
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
      form_data.merge(participant_id: nil)
    end

    def veteran
      { participant_id: nil }
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
      path = "/tmp/#{signature_type}_signature.png"
      File.open(path, 'wb') do |f|
        f.write(Base64.decode64(form_data[signature_type]))
      end
      signature_image_paths[signature_type] = path
    end

    def self.pending?(id)
      query = where(id: id)
      query.exists? ? query.first : false
    end
  end
end
