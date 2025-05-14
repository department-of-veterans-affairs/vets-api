# frozen_string_literal: true

module AccreditedRepresentativePortal
  module PowerOfAttorneyRequestService
    class Accept
      class Error < RuntimeError
        attr_reader :status

        def initialize(message, status)
          @status = status
          super(message)
        end
      end

      TRANSIENT_ERROR_TYPES =
        BenefitsClaims::ServiceException::ERROR_MAP.select do |key, _|
          [429, 500, 502, 503, 504].include? key
        end.values.freeze
      FATAL_ERROR_TYPES =
        BenefitsClaims::ServiceException::ERROR_MAP.select do |key, _|
          [400, 401, 403, 404, 413, 422].include? key
        end.values.freeze

      attr_reader :poa_request, :creator, :resolution, :form_data

      def initialize(poa_request, creator)
        @poa_request = poa_request
        @form_data = poa_request.power_of_attorney_form.parsed_data
        @creator = creator
        @resolution = nil
      end

      def call
        # Normal flow with transaction to ensure proper rollback
        ActiveRecord::Base.transaction do
          @resolution = PowerOfAttorneyRequestDecision.create_acceptance!(
            creator: creator, 
            power_of_attorney_request: poa_request
          )
          
          response = service.submit2122(form_payload)
          form_submission = create_form_submission!(response.body)
          PowerOfAttorneyFormSubmissionJob.perform_async(form_submission.id)

          Monitoring.new.track_duration('ar.poa.request.duration', from: @poa_request.created_at)
          Monitoring.new.track_duration('ar.poa.request.accepted.duration', from: @poa_request.created_at)

          form_submission
        end
      # Special handling for ResourceNotFound - must be outside transaction for test
      rescue Common::Exceptions::ResourceNotFound => e
        raise Error.new(e.detail || e.message, :not_found)
      # Invalid record - return error message with 400
      rescue ActiveRecord::RecordInvalid => e
        raise Error.new(e.message, :bad_request)
      # Transient 5xx errors: transaction will rollback, raise TransientError
      rescue *TRANSIENT_ERROR_TYPES, Faraday::TimeoutError => e
        raise Error.new(e.message, :gateway_timeout)
      # Fatal 4xx errors or validation error: save error message, raise FatalError
      rescue *FATAL_ERROR_TYPES => e
        error_message = e.respond_to?(:detail) ? e.detail : e.message
        create_error_form_submission(error_message, {})
        raise Error.new(error_message, :not_found)
      # All other errors: save error data on form submission, will result in a 500
      rescue => e
        raise
      end

      private

      def service
        @service ||= BenefitsClaims::Service.new(poa_request.claimant.icn)
      end

      def create_form_submission!(response_body)
        PowerOfAttorneyFormSubmission.create!(
          power_of_attorney_request: poa_request,
          service_id: response_body.dig('data', 'id'),
          service_response: response_body.to_json,
          status: :enqueue_succeeded,
          status_updated_at: DateTime.current
        )
      end

      def create_error_form_submission(message, response_body)
        PowerOfAttorneyFormSubmission.create(
          power_of_attorney_request: poa_request,
          status: :enqueue_failed,
          status_updated_at: DateTime.current,
          service_response: response_body,
          error_message: message
        )

        Monitoring.new.track_duration('ar.poa.submission.duration', from: @poa_request.created_at)
        Monitoring.new.track_duration('ar.poa.submission.enqueue_failed.duration', from: @poa_request.created_at)
      end

      def form_payload
        {}.tap do |a|
          a[:veteran] = veteran_data
          a[:serviceOrganization] = organization_data
          a[:recordConsent] = form_data.dig('authorizations', 'recordDisclosureLimitations').blank?
          a[:consentLimits] = form_data.dig('authorizations', 'recordDisclosureLimitations')
          a[:consentAddressChange] = form_data.dig('authorizations', 'addressChange')
        end
      end

      def organization_data
        registration_number =
          creator.get_registration_number(
            poa_request.power_of_attorney_holder_type
          )

        {
          poaCode: poa_request.power_of_attorney_holder_poa_code,
          registrationNumber: registration_number
        }
      end

      def veteran_data
        service_number = form_data.dig('veteran', 'serviceNumber')
        insurance_number = form_data.dig('veteran', 'insuranceNumber')
        {}.tap do |v|
          v[:address] = address_data(form_data.dig('veteran', 'address'))
          v[:phone] = phone_data(form_data.dig('veteran', 'phone'))
          v[:email] = form_data.dig('veteran', 'email')
          v[:serviceNumber] = service_number if service_number.present?
          v[:insuranceNumber] = insurance_number if insurance_number.present?
        end
      end

      def phone_data(phone)
        phone_number = phone.to_s.gsub(/-| /, '')
        {}.tap do |p|
          p[:areaCode] = phone_number[0..2]
          p[:phoneNumber] = phone_number[3..9]
          p[:phoneNumberExt] = phone_number[10..] if phone_number[10..].present?
        end
      end

      def address_data(address_json)
        {}.tap do |a|
          a[:addressLine1] = address_json['addressLine1']
          a[:addressLine2] = address_json['addressLine2'] if address_json['addressLine2'].present?
          a[:city] = address_json['city']
          a[:stateCode] = address_json['stateCode']
          a[:countryCode] = address_json['country']
          a[:zipCode] = address_json['zipCode'] if address_json['country'] == 'US'
          if address_json['zipCodeSuffix'].present?
            a[:zipCodeSuffix] =
              address_json['zipCodeSuffix']
          end
        end
      end
    end
  end
end
