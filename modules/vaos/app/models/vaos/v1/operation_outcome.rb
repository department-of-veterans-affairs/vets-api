# frozen_string_literal: true

module VAOS
  module V1
    class OperationOutcome
      attr_reader :resource_type, :issue

      def initialize(resource_type, issue)
        @resource_type = resource_type
        @issue = issue
      end
    end
  end
end
