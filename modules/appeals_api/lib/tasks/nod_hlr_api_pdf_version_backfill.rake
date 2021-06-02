# frozen_string_literal: true

# rakelib/nod_hlr_api_pdf_version_backfill.rake

require 'appeals_api/data_migrations/api_pdf_versions'

desc 'backfill v1 for all preexisting NOD HLRs'
namespace :data_migration do
  task nod_hlr_api_pdf_version_backfill: :environment do
    AppealsApi::DataMigrations::ApiPdfVersions.run
  end
end
