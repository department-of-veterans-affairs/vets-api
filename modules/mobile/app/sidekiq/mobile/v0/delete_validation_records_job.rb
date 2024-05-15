# frozen_string_literal: true

module Mobile
  module V0
    class DeleteValidationRecordsJob
      include Sidekiq::Job

      sidekiq_options(retry: false)

      def perform(uuid)
        SchemaContract::Validation.where(updated_at: ..1.week.ago).destroy_all
      end
    end
  end
end
