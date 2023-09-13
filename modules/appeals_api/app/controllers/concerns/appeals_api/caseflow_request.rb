# frozen_string_literal: true

module AppealsApi
  module CaseflowRequest
    extend ActiveSupport::Concern

    # Redefine this in the including controller
    def get_caseflow_response
      raise 'Unable to get response from caseflow'
    end

    def caseflow_response
      @caseflow_response ||= get_caseflow_response
    rescue Common::Exceptions::BackendServiceException => e
      log_caseflow_error('BackendServiceException', e)
      # Try to raise a known type of exception from Common::Exceptions before returning an error response
      try_to_raise_common_error(e)
      @caseflow_response = caseflow_exception_to_valid_response(e)
    end

    # Optionally use this to find SSN for use in the Caseflow request
    def icn_to_ssn!(icn)
      res = MPI::Service.new.find_profile_by_identifier(identifier: icn, identifier_type: MPI::Constants::ICN)
      raise_unusable_response('MPI') if res.status == :server_error

      ssn = res.profile&.ssn
      raise_veteran_not_found if ssn.blank?

      ssn
    end

    private

    def caseflow_service
      @caseflow_service ||= Caseflow::Service.new
    end

    # Extracts a renderable error response from a BackendServiceException error object.
    # Because BackendServiceException exposes more fields than necessary in the Caseflow response body, this method also
    # filters it to only the "errors" list where possible, formatting each error to fit our schema.
    def caseflow_exception_to_valid_response(caseflow_error)
      body = caseflow_error.original_body

      if (errors = body['errors'].presence)
        # Caseflow 4xx errors have many of the same attributes as ours, but not 'code'
        body = { 'errors' => errors.map { |obj| obj.merge!({ 'code' => obj['status'] }) } }
      end

      Struct.new(:status, :body).new(caseflow_error.original_status, body.deep_transform_values(&:to_s))
    end

    def log_caseflow_error(error_reason, caseflow_error)
      Rails.logger.error(
        "#{self.class.name} Caseflow::Service error: #{error_reason}",
        caseflow_status: caseflow_error.original_status,
        caseflow_body: caseflow_error.original_body
      )
    end

    def try_to_raise_common_error(caseflow_error)
      status = caseflow_error.original_status.to_i

      # Avoid exposing 5XX errors to the user:
      raise_unusable_response('Caseflow') unless status.between?(400, 499)

      # By default, the Caseflow 404 message includes reference to the SSN - our users have supplied an ICN instead,
      # so reraise a generic 404 here:
      raise_veteran_not_found if status == 404
    end

    def raise_unusable_response(service_name)
      raise Common::Exceptions::BadGateway, detail: "Received an unusable response from #{service_name}"
    end

    def raise_veteran_not_found
      raise Common::Exceptions::ResourceNotFound,
            title: 'Veteran not found',
            detail: 'A matching Veteran was not found in our systems'
    end
  end
end
