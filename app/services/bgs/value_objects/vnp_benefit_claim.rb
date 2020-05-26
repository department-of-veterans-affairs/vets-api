# frozen_string_literal: true

module Types
  include Dry.Types
end

module ValueObjects
  class VnpBenefitClaim < Dry::Struct
    attribute :vnp_proc_id, Types::String # need
    attribute :vnp_benefit_claim_id, Types::String # need
    attribute :vnp_benefit_claim_type_code, Types::String # need
    attribute :claim_jrsdtn_lctn_id, Types::String # need
    attribute :intake_jrsdtn_lctn_id, Types::String # need
    # attribute :claim_received_date, Types::Nominal::DateTime
    # attribute :program_type_code, Types::String
    attribute :participant_claimant_id, Types::String # need
    # attribute :status_type_code, Types::String
    # attribute :service_type_code, Types::String
    # attribute :participant_mail_address_id, Types::String
    # attribute :vnp_participant_vet_id, Types::String
  end
end