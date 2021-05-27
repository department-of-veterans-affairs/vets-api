module AppealsApi
  module DataMigrations
    module ApiPdfVersions
      module_function

      def run
        AppealsApi::HigherLevelReview.
          update_all(pdf_version: 'V1', api_version: 'V1')
        AppealsApi::NoticeOfDisagreement.
          update_all(pdf_version: 'V1', api_version: 'V1')
      end
    end
  end
end
