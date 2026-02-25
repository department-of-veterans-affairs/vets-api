# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantDetailsService
    def initialize(icn:, benefit_type_param: nil)
      @icn = icn
      @benefit_type_param = benefit_type_param
    end

    def call
      mpi_promise = Concurrent::Promises.future { claimant_profile_by_icn(@icn) }

      itf_types = itf_types_from_param(@benefit_type_param)
      itf_promises = itf_types.map do |benefit_type|
        Concurrent::Promises.future { safe_intent_to_file(@icn, benefit_type) }
      end

      profile = mpi_promise.value!
      raise Common::Exceptions::RecordNotFound, 'Claimant not found' if profile.blank?

      payload = claimant_payload(profile)
      payload[:data][:itf] = itf_promises.map(&:value).compact
      payload
    end

    private

    def intent_to_file_check_service(icn)
      @intent_to_file_check_service ||= BenefitsClaims::Service.new(icn)
    end

    def claimant_profile_by_icn(icn)
      MPI::Service.new.find_profile_by_identifier(
        identifier: icn,
        identifier_type: MPI::Constants::ICN
      )&.profile
    end

    def itf_types_from_param(type)
      return [type] if type.present?

      %w[compensation pension survivor]
    end

    def safe_intent_to_file(icn, benefit_type)
      intent_to_file_check_service(icn).get_intent_to_file(benefit_type)
    rescue => e
      Rails.logger.warn(
        'ClaimantDetailsService ITF lookup failed',
        { icn:, benefit_type:, error: e.class.name, message: e.message }
      )
      nil
    end

    def claimant_payload(profile)
      {
        data: {
          first_name: profile.given_names&.first,
          last_name: profile.family_name,
          birth_date: profile.birth_date,
          ssn: profile.ssn,
          phone: profile.home_phone,
          address: claimant_address(profile)
        }
      }
    end

    def claimant_address(profile)
      addr = profile.address
      {
        line1: addr&.street,
        line2: addr&.street2,
        city: addr&.city,
        state: addr&.state,
        zip: addr&.postal_code
      }
    end
  end
end
