# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V1
    # FHIR (DSTU 2) Operation Outcome model. Wrapped for exceptions so they can be
    # later serialized in the expected FHIR format
    # http://hl7.org/fhir/DSTU2/operationoutcome.html
    #
    # The issue must first be wrapped in a VAOS::V1::OperationOutcome which is passed to the serializer.
    # This serializer takes errors that intended for JSON API rendering and remaps their fields.
    #
    # @example wrap a BackendServiceException in an outcome
    #   issue = Common::Exceptions::BackendServiceException.new('VAOS_502', source: 'Klass')
    #   operation_outcome = VAOS::V1::OperationOutcome.new(resource_type: 'Organization', id: '123', issue: issue)
    class OperationOutcome
      attr_reader :resource_type, :id, :issue

      # Creates a new OperationOutcome instance
      # @param resource_type String the resource type the operation is reporting on
      # @param id String the id, if available, of the resource
      # @param issue StandardError the original error that caused the issue
      # @return issue VAOS::V1::OperationOutcome the instance
      def initialize(resource_type:, issue:, id: nil)
        @resource_type = resource_type
        @id = id
        @issue = issue
      end
    end
  end
end
