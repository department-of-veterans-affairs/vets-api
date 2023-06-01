# frozen_string_literal: true

namespace :vba_documents do
  namespace :data_migration do
    desc('Scrubs doc_type from the metadata of all UploadSubmission records')

    task scrub_doc_type_from_metadata: :environment do
      # rubocop:disable Rails/SkipsModelValidations
      VBADocuments::UploadSubmission.in_batches.update_all("uploaded_pdf = uploaded_pdf::jsonb - 'doc_type'")
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
