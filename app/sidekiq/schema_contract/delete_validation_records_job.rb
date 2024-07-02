# frozen_string_literal: true

module SchemaContract
  class DeleteValidationRecordsJob
    include Sidekiq::Job

    sidekiq_options(retry: false)

    def perform
      SchemaContract::Validation.where(updated_at: ..1.month.ago).destroy_all
    end
  end
end
