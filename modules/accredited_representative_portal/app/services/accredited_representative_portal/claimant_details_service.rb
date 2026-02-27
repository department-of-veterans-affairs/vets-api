# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantDetailsService
    def initialize(icn:, benefit_type_param: nil)
      @icn = icn
      @benefit_type_param = benefit_type_param
    end

    def call
      profile = claimant_profile_by_icn(@icn)
      raise Common::Exceptions::RecordNotFound, 'Claimant not found' if profile.blank?

      payload = claimant_payload(profile)

      itf_types = itf_types_from_param(@benefit_type_param)
      itf_results = itf_types.map { |benefit_type| safe_intent_to_file(@icn, benefit_type) }.compact

      payload[:data][:itf] = itf_results
      payload
    end

    private

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
      BenefitsClaims::Service.new(icn).get_intent_to_file(benefit_type)
    rescue => e
      # Avoid logging e.message to reduce the risk of unintentionally exposing
      # sensitive data from upstream services (e.g., identifiers in error text).
      Rails.logger.warn(
        'ClaimantDetailsService ITF lookup failed',
        { benefit_type:, error: e.class.name }
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
