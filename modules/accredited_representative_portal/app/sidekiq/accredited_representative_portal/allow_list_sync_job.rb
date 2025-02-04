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

      MODEL.transaction do
        # Get incoming registration numbers
        incoming_registration_numbers = csv_data.map { |row| row['accredited_individual_registration_number'] }

        # Delete records not in the incoming data
        deleted_count = MODEL.where.not(
          accredited_individual_registration_number: incoming_registration_numbers
        ).delete_all

        # Build and validate all records before insert
        new_records = csv_data.map do |row|
          MODEL.new(row.to_h.slice(*SYNC_FIELDS)).tap(&:validate!)
        end

        # Insert with conflict handling
        inserted = MODEL.insert_all(
          new_records.map { |r| r.attributes.slice(*SYNC_FIELDS) },
          returning: SYNC_FIELDS,
          unique_by: SYNC_FIELDS
        )

        {
          deleted_count: deleted_count,
          inserted_count: inserted.rows.length
        }
      end
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
