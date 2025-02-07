# frozen_string_literal: true

module AccreditedRepresentativePortal
  module PowerOfAttorneyRequestService
    class Accept
      attr_reader :poa_request, :creator, :reason, :resolution
      attr_accessor :form_submission

      def initialize(poa_request, creator, reason)
        @poa_request = poa_request
        @creator = creator
        @reason = reason
      end

      def call
        ApplicationRecord.transaction do
          create_resolution!
          create_form_submission!
        end

        service = BenefitsClaims::Service.new(poa_request.claimant.icn)
        response = service.submit2122(attributes)

        form_submission.update(
          service_id: response.body.dig('data', 'id'),
          service_response: response.body.to_json
        )

        form_submission.tap do |s|
          PowerOfAttorneyFormSubmissionJob.perform_async(s.id)
        end
      # Transient 5xx errors: delete objects created, re-raise error
      rescue *transient_error_types => e
        form_submission.delete
        resolution.delete
        raise e
      # All other errors: save error data on form submission
      rescue => e
        create_error_submission(e.message)
        raise e
      end

      def create_resolution!
        resolving = PowerOfAttorneyRequestDecision.create!(
          type: PowerOfAttorneyRequestDecision::Types::ACCEPTANCE, creator:
        )
        ##
        # This form triggers the uniqueness validation, while the
        # `@poa_request.create_resolution!` form triggers a more obscure
        # `RecordNotSaved` error that is less functional for getting
        # validation errors.
        #
        @resolution = PowerOfAttorneyRequestResolution.create!(
          power_of_attorney_request: poa_request,
          resolving:,
          reason:
        )
      end

      def create_form_submission!
        @form_submission = PowerOfAttorneyFormSubmission.create!(
          power_of_attorney_request: poa_request,
          status: :enqueue_succeeded,
          status_updated_at: DateTime.current
        )
      end

      def create_error_submission(message)
        PowerOfAttorneyFormSubmission.create(
          service_response: message,
          error_message: message,
          status: :enqueue_failed,
          status_updated_at: DateTime.current
        )
      end

      def attributes
        {}.tap do |a|
          a[:veteran] = veteran_data
          a[:serviceOrganization] = service_org_data
          a[:recordConsent] = form_data.dig('authorizations', 'recordDisclosure')
          a[:consentLimits] = form_data.dig('authorizations', 'recordDisclosureLimitations')
          a[:consentAddressChange] = form_data.dig('authorizations', 'addressChange')
        end
      end

      def service_org_data
        {
          poaCode: poa_request.power_of_attorney_holder_poa_code,
          registrationNumber: poa_request.accredited_individual_registration_number
        }
      end

      def form_data
        @form_data ||= JSON.parse(poa_request.power_of_attorney_form.data)
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

      def transient_error_types
        BenefitsClaims::ServiceException::ERROR_MAP.select { |key, _| key >= 500 }.values
      end
    end
  end
end
