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
        perform_transaction
      rescue Common::Exceptions::ResourceNotFound => e
        handle_resource_not_found(e)
      rescue ActiveRecord::RecordInvalid => e
        handle_record_invalid(e)
      rescue *TRANSIENT_ERROR_TYPES, Faraday::TimeoutError => e
        handle_transient_error(e)
      rescue *FATAL_ERROR_TYPES => e
        handle_fatal_error(e)
      rescue => e
        handle_unexpected_error(e)
      end

      private

      def perform_transaction
        ActiveRecord::Base.transaction do
          @resolution = create_acceptance
          response = submit_form
          form_submission = create_form_submission!(response.body)
          enqueue_form_processing(form_submission)
          track_acceptance_metrics
          form_submission
        end
      end

      def create_acceptance
        PowerOfAttorneyRequestDecision.create_acceptance!(
          creator:,
          power_of_attorney_request: poa_request
        )
      end

      def submit_form
        service.submit2122(form_payload)
      end

      def enqueue_form_processing(form_submission)
        PowerOfAttorneyFormSubmissionJob.perform_async(form_submission.id)
      end

      def track_acceptance_metrics
        Monitoring.new.track_duration('ar.poa.request.duration', from: @poa_request.created_at)
        Monitoring.new.track_duration('ar.poa.request.accepted.duration', from: @poa_request.created_at)
      end

      def handle_resource_not_found(error)
        raise Error.new(error.detail || error.message, :not_found)
      end

      def handle_record_invalid(error)
        raise Error.new(error.message, :bad_request)
      end

      def handle_transient_error(error)
        raise Error.new(error.message, :gateway_timeout)
      end

      def handle_fatal_error(error)
        error_message = error.respond_to?(:detail) ? error.detail : error.message
        create_error_form_submission(error_message, {})
        raise Error.new(error_message, :not_found)
      end

      def handle_unexpected_error(error)
        Rails.logger.error("Unexpected error in Accept#call: #{error.class} - #{error.message}")
        Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
        create_error_form_submission(error.message, {})
        raise
      end

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
