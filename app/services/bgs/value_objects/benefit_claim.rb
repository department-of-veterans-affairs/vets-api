# frozen_string_literal: true

module Types
  include Dry.Types
end

module ValueObjects
  class BenefitClaim < Dry::Struct
    attribute :benefit_claim_id, Types::String # need
    # attribute :corp_benefit_claim_id, Types::String
    # attribute :corp_claim_id, Types::String
    # attribute :corp_location_id, Types::String
    # attribute :benefit_claim_return_label, Types::String
    # attribute :claim_receive_date, Types::String
    # attribute :claim_station_of_jurisdiction, Types::String
    attribute :claim_type_code, Types::String # need
    # attribute :claim_type_name, Types::String
    # attribute :claimant_first_name, Types::String
    # attribute :claimant_last_name, Types::String
    # attribute :claimant_person_or_organization_indicator, Types::String
    # attribute :corp_claim_return_label, Types::String
    # attribute :end_product_type_code, Types::String
    # attribute :mailing_address_id, Types::String
    attribute :participant_claimant_id, Types::String # need
    # attribute :participant_vet_id, Types::String
    # attribute :payee_type_code, Types::String
    attribute :program_type_code, Types::String # need
    # attribute :return_code, Types::String
    attribute :service_type_code, Types::String # need
    attribute :status_type_code, Types::String # need
    # attribute :vet_first_name, Types::String
    # attribute :vet_last_name, Types::String
  end
end
