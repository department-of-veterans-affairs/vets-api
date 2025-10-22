# frozen_string_literal: true

module DependentsBenefits
  class ServiceResponse
    attr_reader :status, :data, :error

    def initialize(status:, data: nil, error: nil)
      @status = status
      @data = data
      @error = error
    end

    def success?
      status
    end
  end
end
