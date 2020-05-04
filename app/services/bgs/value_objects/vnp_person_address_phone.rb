# frozen_string_literal: true

module Types
  include Dry.Types
end

module ValueObjects
  class VnpPersonAddressPhone < Dry::Struct
    attribute :vnp_proc_id, Types::String
    attribute :vnp_participant_id, Types::String
    attribute :first_name, Types::String
    attribute :middle_name, Types::String
    attribute :last_name, Types::String
    attribute :vnp_participant_address_id, Types::String.optional
    attribute :participant_relationship_type_name, Types::String.optional
    attribute :family_relationship_type_name, Types::String.optional
    attribute :suffix_name, Types::String.optional
    attribute :birth_date, Types::Nominal::DateTime
    attribute :birth_state_code, Types::String.optional
    attribute :birth_city_name, Types::String.optional
    attribute :file_number, Types::String.optional
    attribute :ssn_number, Types::String.optional
    attribute :phone_number, Types::String.optional
    attribute :address_line_one, Types::String.optional
    attribute :address_line_two, Types::String.optional
    attribute :address_line_three, Types::String.optional
    attribute :address_state_code, Types::String.optional
    attribute :address_country, Types::String.optional
    attribute :address_city, Types::String.optional
    attribute :address_zip_code, Types::String.optional
    attribute :email_address, Types::String.optional
    attribute :death_date, Types::DateTime.optional
    attribute :begin_date, Types::String.optional
    attribute :end_date, Types::DateTime.optional
    attribute :event_date, Types::String.optional
    attribute :ever_married_indicator, Types::String.optional
    attribute :marriage_state, Types::String.optional
    attribute :marriage_city, Types::String.optional
    attribute :divorce_state, Types::String.optional
    attribute :divorce_city, Types::String.optional
    attribute :marriage_termination_type_code, Types::String.optional
    attribute :benefit_claim_type_end_product, Types::String.optional
    attribute :living_expenses_paid_amount, Types::String.optional
  end
end