# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Error < StandardError
      RecordNotFound = Class.new(self)
    end
  end
end
