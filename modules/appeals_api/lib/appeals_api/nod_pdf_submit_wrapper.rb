# frozen_string_literal: true

module AppealsApi
  class NodPdfSubmitWrapper < SimpleDelegator
    include AppealsApi::CharacterUtilities

    def metadata(pdf_path)
      notice_of_disagreement = __getobj__
      {
        'veteranFirstName' => transliterate_for_centralmail(notice_of_disagreement.veteran_first_name),
        'veteranLastName' => transliterate_for_centralmail(notice_of_disagreement.veteran_last_name),
        'fileNumber' => notice_of_disagreement.file_number.presence || notice_of_disagreement.ssn,
        'zipCode' => notice_of_disagreement.zip_code_5,
        'source' => "Appeals-NOD-#{notice_of_disagreement.consumer_name}",
        'uuid' => notice_of_disagreement.id,
        'hashV' => Digest::SHA256.file(pdf_path).hexdigest,
        'numberAttachments' => 0,
        'receiveDt' => receive_date(notice_of_disagreement),
        'numberPages' => PdfInfo::Metadata.read(pdf_path).pages,
        'docType' => '10182',
        'lob' => notice_of_disagreement.lob
      }
    end

    def receive_date(notice_of_disagreement)
      notice_of_disagreement
        .created_at
        .in_time_zone('Central Time (US & Canada)')
        .strftime('%Y-%m-%d %H:%M:%S')
    end

    def pdf_file_name
      '10182-document.pdf'
    end
  end
end
