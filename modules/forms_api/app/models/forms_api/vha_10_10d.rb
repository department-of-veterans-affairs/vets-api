# frozen_string_literal: true

module FormsApi
  class VHA1010d
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata(pdf_path)
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code'),
        'source' => 'forms_api',
        'uuid' => SecureRandom.uuid,
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        'numberAttachments' => 0,
        'receiveDt' => Time.zone.now.strftime('%Y-%m-%d %H:%M:%S'),
        'numberPages' => PdfInfo::Metadata.read(pdf_path).pages,
        'businessLine' => 'CMP',
        'docType' => @data['form_number']
      }
    end
  end
end
