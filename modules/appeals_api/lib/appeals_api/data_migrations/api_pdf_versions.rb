# frozen_string_literal: true

module AppealsApi
  module DataMigrations
    module ApiPdfVersions
      module_function

      # rubocop:disable Rails/SkipsModelValidations
      def run
        AppealsApi::HigherLevelReview
          .update_all(pdf_version: 'V1', api_version: 'V1')
        AppealsApi::NoticeOfDisagreement
          .update_all(pdf_version: 'V1', api_version: 'V1')
      end
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
