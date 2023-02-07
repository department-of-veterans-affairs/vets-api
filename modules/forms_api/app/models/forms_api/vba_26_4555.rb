# frozen_string_literal: true

module FormsApi
  class FormsApi::VBA264555
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata(pdf_path)
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data['va_file_number'],
        'zipCode' => '00000',
        'source' => 'va.gov',
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        'numberAttachments' => 0,
        'receiveDt' => Time.zone.now.strftime('%Y-%m-%d %H:%M%S'),
        'numberPages' => PdfInfo::Metadata.read(pdf_path).pages,
        'docType' => '10182',
        'businessLine' => @data['form_number'].split('_').first.upcase
      }
    end
  end
end
