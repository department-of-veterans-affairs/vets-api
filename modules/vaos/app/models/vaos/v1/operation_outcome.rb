# frozen_string_literal: true

module VAOS
  module V1
    class OperationOutcome
      attr_reader :resource_type, :id, :issue

      def initialize(resource_type:, id: nil, issue:)
        @resource_type = resource_type
        @id = id
        @issue = issue
      end
    end
  end
end
