# frozen_string_literal: true

namespace :vba_documents do
  namespace :data_migration do
    desc('Scrubs doc_type from the metadata of all UploadSubmission records')

    task scrub_doc_type_from_metadata: :environment do
      ActiveRecord::Base.connection.execute("
        UPDATE vba_documents_upload_submissions
        SET uploaded_pdf = uploaded_pdf::jsonb - 'doc_type';
      ")
    end
  end
end
