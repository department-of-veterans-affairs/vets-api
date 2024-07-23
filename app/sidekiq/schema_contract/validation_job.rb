# frozen_string_literal: true

module SchemaContract
  class ValidationJob
    include Sidekiq::Job

    sidekiq_options(retry: false)

    def perform(contract_name)
      SchemaContract::Validator.new(contract_name).validate
    end
  end
end
