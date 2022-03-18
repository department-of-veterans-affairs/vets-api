# frozen_string_literal: true

module AppealsApi
  class ScPdfSubmitWrapper < SimpleDelegator
    include AppealsApi::CharacterUtilities

    def metadata(pdf_path)
      supplemental_claim = __getobj__
      {
        'veteranFirstName' => transliterate_for_centralmail(supplemental_claim.veteran_first_name),
        'veteranLastName' => transliterate_for_centralmail(supplemental_claim.veteran_last_name),
        'fileNumber' => supplemental_claim.file_number.presence || supplemental_claim.ssn,
        'zipCode' => supplemental_claim.zip_code_5,
        'source' => "Appeals-SC-#{supplemental_claim.consumer_name}",
        'uuid' => supplemental_claim.id,
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        'numberAttachments' => 0,
        'receiveDt' => receive_date(supplemental_claim),
        'numberPages' => PdfInfo::Metadata.read(pdf_path).pages,
        'businessLine' => supplemental_claim.lob,
        'docType' => '20-0995'
      }
    end

    def receive_date(supplemental_claim)
      supplemental_claim
        .created_at
        .in_time_zone('Central Time (US & Canada)')
        .strftime('%Y-%m-%d %H:%M:%S')
    end

    def pdf_file_name
      '200995-document.pdf'
    end
  end
end
