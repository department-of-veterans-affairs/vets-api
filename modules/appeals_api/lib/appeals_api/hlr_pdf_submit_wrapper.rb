# frozen_string_literal: true

module AppealsApi
  class HlrPdfSubmitWrapper < SimpleDelegator
    include AppealsApi::CharacterUtilities

    def metadata(pdf_path)
      higher_level_review = __getobj__
      {
        'veteranFirstName' => transliterate_for_centralmail(higher_level_review.first_name),
        'veteranLastName' => transliterate_for_centralmail(higher_level_review.last_name),
        'fileNumber' => higher_level_review.file_number.presence || higher_level_review.ssn,
        'zipCode' => higher_level_review.zip_code_5,
        'source' => "Appeals-HLR-#{higher_level_review.consumer_name}",
        'uuid' => higher_level_review.id,
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        'numberAttachments' => 0,
        'receiveDt' => receive_date(higher_level_review),
        'numberPages' => PdfInfo::Metadata.read(pdf_path).pages,
        'docType' => '20-0996'
      }
    end

    def receive_date(higher_level_review)
      higher_level_review
        .created_at
        .in_time_zone('Central Time (US & Canada)')
        .strftime('%Y-%m-%d %H:%M:%S')
    end

    def pdf_file_name
      '200996-document.pdf'
    end
  end
end
