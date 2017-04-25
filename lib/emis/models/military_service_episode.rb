# frozen_string_literal: true

module EMIS
  module Models
    class MilitaryServiceEpisode
      include Virtus.model

      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :termination_reason, String
      attribute :branch_of_service_code, String
      attribute :retirement_type_code, String
      attribute :personnel_projected_end_date, Date
      attribute :personnel_projected_end_date_certainty_code, String
      attribute :discharge_character_of_service_code, String
      attribute :honorable_discharge_for_va_purpose_code, String
      attribute :personnel_status_change_transaction_type_code, String
      attribute :narrative_reason_for_separation_code, String
      attribute :post911_gi_bill_loss_category_code, String
      attribute :mgad_loss_category_code, String
      attribute :active_duty_service_agreement_quantity, String
      attribute :initial_entry_training_end_date, Date
      attribute :uniform_service_initial_entry_date, Date
      attribute :military_accession_source_code, String
      attribute :personnel_begin_date_source, String
      attribute :personnel_termination_date_source_code, String
      attribute :active_federal_military_service_base_date, Date
      attribute :mgsr_service_agreement_duration_year_quantity_code, String
      attribute :dod_beneficiary_type_code, String
      attribute :reserve_under_age60_code, String
    end
  end
end
