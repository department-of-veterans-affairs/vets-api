# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/concerns/service_status'
require 'mpi/errors/errors'

module Users
  class ExceptionHandler
    include Common::Client::Concerns::ServiceStatus

    attr_reader :error, :service

    # @param error [ErrorClass] An external service error
    # @param service [String] The name of the external service (i.e. 'Vet360', 'MVI', 'EMIS')
    #
    def initialize(error, service)
      @error = validate!(error)
      @service = service
    end

    # Serializes the initialized error into one of the predetermined error types.
    # Uses error classes that can be triggered by MVI, EMIS, or Vet360.
    #
    # The serialized error format is modelled after the Maintenance Windows schema,
    # per the FE's request.
    #
    # @return [Hash] A serialized version of the initialized error. Follows maintenance
    # window schema.
    # @see https://department-of-veterans-affairs.github.io/va-digital-services-platform-docs/api-reference/#/site/getMaintenanceWindows
    #
    def serialize_error
      case error
      when Common::Exceptions::BaseError
        base_error
      when Common::Client::Errors::ClientError
        client_error
      when EMISRedis::VeteranStatus::NotAuthorized
        emis_error(:not_authorized)
      when EMISRedis::VeteranStatus::RecordNotFound
        emis_error(:not_found)
      when MPI::Errors::RecordNotFound
        mpi_error(404)
      when MPI::Errors::FailedRequestError
        mpi_error(503)
      when MPI::Errors::DuplicateRecords
        mpi_error(404)
      else
        standard_error
      end
    end

    private

    def validate!(error)
      raise Common::Exceptions::ParameterMissing.new('error'), 'error' if error.blank?

      error
    end

    def base_error
      exception = error.errors.first

      error_template.merge(
        description: "#{exception.code}, #{exception.status}, #{exception.title}, #{exception.detail}",
        status: exception.status.to_i
      )
    end

    def client_error
      error_template.merge(
        description: "#{error.class}, #{error.status}, #{error.message}, #{error.body}",
        status: error.status.to_i
      )
    end

    def emis_error(type)
      error_template.merge(
        description: "#{error.class}, #{RESPONSE_STATUS[type]}",
        status: error.status.to_i
      )
    end

    def mpi_error(status)
      error_template.merge(
        description: "#{error.class}, #{error.message}",
        status:
      )
    end

    def standard_error
      error_template.merge(
        description: "#{error.class}, #{error.message}, #{error}",
        status: standard_error_status(error)
      )
    end

    def error_template
      {
        external_service: service,
        start_time: Time.current.iso8601,
        end_time: nil,
        description: nil,
        status: nil
      }
    end

    def standard_error_status(error)
      error.try(:status).presence ||
        error.try(:status_code).presence ||
        error.try(:code).presence ||
        503
    end
  end
end
