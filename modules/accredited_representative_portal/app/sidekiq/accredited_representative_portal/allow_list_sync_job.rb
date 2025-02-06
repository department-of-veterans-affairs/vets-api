# frozen_string_literal: true

module AccreditedRepresentativePortal
  class AllowListSyncJob
    include Sidekiq::Job

    MODEL = UserAccountAccreditedIndividual
    MAX_CSV_ROWS = 500

    SYNC_FIELDS = %w[
      accredited_individual_registration_number
      power_of_attorney_holder_type
      user_account_email
    ].freeze

    class InvalidRowCount < StandardError; end

    def perform
      csv_data = fetch_csv
      raise InvalidRowCount, 'Empty CSV data received' if csv_data.blank?

      stats = sync_from_csv!(csv_data)

      Rails.logger.info(
        'Successfully synced accredited individuals. ' \
        "Replaced #{stats[:deleted_count]} records with #{stats[:inserted_count]} records."
      )
    rescue => e
      Rails.logger.error(
        "Error syncing accredited individuals: #{e.message}\n" \
        "Backtrace: #{e.backtrace.first(5).join("\n")}"
      )
      raise
    end

    private

    # rubocop:disable Rails/SkipsModelValidations, Metrics/MethodLength
    def sync_from_csv!(csv_data)
      if csv_data.size > MAX_CSV_ROWS
        raise InvalidRowCount, "CSV file exceeds maximum allowed rows of (#{MAX_CSV_ROWS})"
      end

      stats = { deleted_count: 0, inserted_count: 0, errored: 0, errors: [] }

      # Build and validate all records before insert
      new_records = csv_data.map do |row|
        MODEL.new(row.to_h.slice(*SYNC_FIELDS)).tap(&:validate!)
      rescue => e
        stats[:errored] += 1
        stats[:errors] << e.message
        next # Skip this record
      end.compact

      return stats if new_records.empty?

      MODEL.transaction do
        # Get incoming rows and convert them to hashes using sync fields
        incoming_data_hashes = csv_data.map { |row| row.to_h.slice(*SYNC_FIELDS) }

        # Prepare the where.not conditions dynamically
        delete_rel = MODEL.where.not(
          incoming_data_hashes.map(&:symbolize_keys)
        )

        # Execute the deletion
        deleted_count = delete_rel.delete_all

        # Insert with conflict handling
        inserted = MODEL.insert_all(
          new_records.map { |r| r.attributes.slice(*SYNC_FIELDS) },
          returning: SYNC_FIELDS,
          unique_by: SYNC_FIELDS
        )

        stats[:deleted_count] = deleted_count
        stats[:inserted_count] = inserted.count
      end

      stats
    end
    # rubocop:enable Rails/SkipsModelValidations, Metrics/MethodLength

    def fetch_csv
      Rails.logger.info "Fetching CSV from GitHub: #{repo} path: #{path}"

      content = github_client.contents(repo, path: path).content
      decoded_content = Base64.decode64(content)

      CSV.parse(decoded_content, headers: true)
    end

    def github_client
      @github_client ||= Octokit::Client.new(
        access_token: Settings.accredited_representative_portal&.allow_list&.github&.access_token
      )
    end

    def repo
      Settings.accredited_representative_portal&.allow_list&.github&.repo
    end

    def path
      Settings.accredited_representative_portal&.allow_list&.github&.path
    end
  end
end
