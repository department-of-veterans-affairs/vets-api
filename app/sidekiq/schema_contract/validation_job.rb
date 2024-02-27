# frozen_string_literal: true

module SchemaContract
  class ValidationJob
    include Sidekiq::Job

    sidekiq_options(retry: false)

    def perform(test_name)
      SchemaContract::Validator.new(test_name).validate
    end
  end
end
