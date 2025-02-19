# frozen_string_literal: true

module AccreditedRepresentativePortal
  class AllowListSyncJob
    include Sidekiq::Job
    sidekiq_options retry: false

    # To not overload the DB.
    MAX_RECORD_COUNT = 500

    Error = Class.new(RuntimeError)

    class RecordCountError < Error
      def initialize(record_count)
        super("record_count: #{record_count}")
      end
    end

    def perform
      SemanticLogger.tagged do
        csv = extract
        csv.size.between?(1, MAX_RECORD_COUNT) or
          raise RecordCountError, csv.size

        attributes = transform!(csv)
        result = load(attributes)

        logger.info(result)
      rescue => e
        logger.error(e)
        raise
      end
    end

    private

    def extract
      config =
        Settings.accredited_representative_portal.allow_list.github

      client =
        Octokit::Client.new(
          api_endpoint: config.base_uri,
          access_token: config.access_token
        )

      client
        .contents(config.repo, path: config.path)
        .then { |contents| Base64.decode64(contents[:content]) }
        .then { |content| CSV.parse(content, headers: true) }
    end

    def transform!(csv)
      csv.map do |row|
        row.to_h.tap do |attrs|
          UserAccountAccreditedIndividual.new(attrs).validate!
        end
      end
    end

    def load(attributes)
      {}.tap do |result|
        unique_by = attributes.first.keys

        UserAccountAccreditedIndividual.transaction do
          result[:deleted_count] =
            UserAccountAccreditedIndividual
            .where.not(unique_by => attributes.map(&:values))
            .delete_all

          result[:inserted_count] =
            UserAccountAccreditedIndividual
            .insert_all(attributes, unique_by:) # rubocop:disable Rails/SkipsModelValidations
            .count
        end
      end
    end
  end
end
