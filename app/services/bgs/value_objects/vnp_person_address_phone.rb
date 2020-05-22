# frozen_string_literal: true

module Types
  include Dry.Types
end

module ValueObjects
  class VnpPersonAddressPhone < Dry::Struct
    attribute :vnp_participant_id, Types::String # keep
    attribute :first_name, Types::String # keep only for veteran
    attribute :last_name, Types::String # keep only for veteran
    attribute :vnp_participant_address_id, Types::String.optional # seems to be only for the veteran used in the benefit claim call
    attribute :participant_relationship_type_name, Types::String.optional # just for dependent
    attribute :family_relationship_type_name, Types::String.optional # just for dependent
    # attribute :suffix_name, Types::String.optional # not needed
    # attribute :birth_date, Types::Nominal::DateTime # not needed
    # attribute :birth_state_code, Types::String.optional # not needed
    # attribute :birth_city_name, Types::String.optional # not needed
    attribute :file_number, Types::String.optional # only needed for veteran
    attribute :ssn_number, Types::String.optional # only needed for veteran
    # attribute :phone_number, Types::String.optional # not needed
    attribute :address_line_one, Types::String.optional # only needed for veteran
    attribute :address_line_two, Types::String.optional # only needed for veteran
    attribute :address_line_three, Types::String.optional # only needed for veteran
    attribute :address_state_code, Types::String.optional # only needed for veteran
    attribute :address_country, Types::String.optional # only needed for veteran
    attribute :address_city, Types::String.optional # only needed for veteran
    attribute :address_zip_code, Types::String.optional # only needed for veteran
    # attribute :email_address, Types::String.optional # not needed
    # attribute :death_date, Types::DateTime.optional # not needed
    attribute :begin_date, Types::String.optional # just for dependent
    attribute :end_date, Types::DateTime.optional # just for dependent
    attribute :event_date, Types::String.optional # just for dependent
    # attribute :ever_married_indicator, Types::String.optional # not needed
    attribute :marriage_state, Types::String.optional # just for dependent
    attribute :marriage_city, Types::String.optional # just for dependent
    attribute :divorce_state, Types::String.optional # just for dependent
    attribute :divorce_city, Types::String.optional # just for dependent
    attribute :marriage_termination_type_code, Types::String.optional # just for dependent
    attribute :benefit_claim_type_end_product, Types::String.optional # just for veteran
    attribute :living_expenses_paid_amount, Types::String.optional # just for dependent
    attribute :type, Types::String # We need this for business logic in this code base
  end
end