# frozen_string_literal: true

module VEText
  # An error representing a 200 response but with error details.
  #
  class ResponseError < StandardError
    def initialize(body)
      @id_type = body&.idType
      @id = body&.id
      super(body&.error || 'Response returned success=false')
    end
  end
end
