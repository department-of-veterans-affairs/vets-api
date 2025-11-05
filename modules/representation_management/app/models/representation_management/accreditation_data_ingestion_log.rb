# frozen_string_literal: true

module RepresentationManagement
  # Tracks the progress and status of accreditation data ingestion processes
  #
  # This class monitors data ingestion from various sources (Accreditation API or Trexler file)
  # and tracks the status of each entity type (agents, attorneys, representatives, VSOs)
  # throughout the ingestion process.
  #
  # @example Creating a new ingestion log
  #   log = AccreditationDataIngestionLog.create!(
  #     dataset: :accreditation_api,
  #     status: :running
  #   )
  #
  # @example Updating entity status
  #   log.agents_status = :success
  #   log.save!
  class AccreditationDataIngestionLog < ApplicationRecord
    self.table_name = 'accreditation_data_ingestion_logs'

    # Dataset sources for accreditation data
    enum :dataset, {
      accreditation_api: 0,
      trexler_file: 1
    }

    # Overall ingestion process status
    enum :status, {
      running: 0,
      success: 1,
      failed: 2
    }

    # Agents ingestion status
    enum :agents_status, {
      not_started: 0,
      running: 1,
      success: 2,
      failed: 3
    }, _prefix: :agents

    # Attorneys ingestion status
    enum :attorneys_status, {
      not_started: 0,
      running: 1,
      success: 2,
      failed: 3
    }, _prefix: :attorneys

    # Representatives ingestion status
    enum :representatives_status, {
      not_started: 0,
      running: 1,
      success: 2,
      failed: 3
    }, _prefix: :representatives

    # Veteran Service Organizations ingestion status
    enum :veteran_service_organizations_status, {
      not_started: 0,
      running: 1,
      success: 2,
      failed: 3
    }, _prefix: :veteran_service_organizations
  end
end
