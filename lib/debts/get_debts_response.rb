# frozen_string_literal: true

module Debts
  class GetDebtsResponse
    attr_reader :debts

    def initialize(res)
      validate_response_against_schema(res)
      @debts = res
    end

    def to_json(*_args)
      @debts.to_json
    end

    private

    def validate_response_against_schema(response)
      schema_path = Rails.root.join('lib', 'debts', 'schemas', 'debts.json').to_s
      JSON::Validator.validate!(schema_path, response, strict: false)
    end
  end
end
