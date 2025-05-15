# frozen_string_literal: true

require 'vets/model'

module Requests
  class Dates
    include Vets::Model

    attribute :begin_date, String
    attribute :end_date, String
  end

  class ContactNumber
    include Vets::Model

    attribute :telephone, String
    attribute :international_telephone, String
  end

  class UnitPhone
    include Vets::Model

    attribute :area_code, String
    attribute :phone_number, String
  end

  class MailingAddress
    include Vets::Model

    # rubocop:disable Naming/VariableNumber
    attribute :address_line_1, String
    attribute :address_line_2, String
    attribute :address_line_3, String
    # rubocop:enable Naming/VariableNumber
    attribute :city, String
    attribute :country, String
    attribute :zip_first_five, String
    attribute :zip_last_four, String
    attribute :state, String
    attribute :international_postal_code, String
  end

  class EmailAddress
    include Vets::Model

    attribute :email, String
    attribute :agree_to_email_related_to_claim, Bool
  end

  class VeteranNumber
    include Vets::Model

    attribute :telephone, String
    attribute :international_telephone, String
  end

  class GulfWarHazardService
    include Vets::Model

    attribute :served_in_gulf_war_hazard_locations, String
    attribute :service_dates, Dates
  end

  class HerbicideHazardService
    include Vets::Model

    attribute :served_in_herbicide_hazard_locations, String
    attribute :other_locations_served, String
    attribute :service_dates, Dates
  end

  class AdditionalHazardExposures
    include Vets::Model

    attribute :additional_exposures, String, array: true
    attribute :specify_other_exposures, String
    attribute :exposure_dates, Dates
  end

  class MultipleExposures
    include Vets::Model

    attribute :exposure_dates, Dates
    attribute :exposure_location, String
    attribute :hazard_exposed_to, String
  end

  class SecondaryDisability
    include Vets::Model

    attribute :name, String
    attribute :disability_action_type, String
    attribute :classification_code, String
    attribute :service_relevance, String
  end

  class Disability
    include Vets::Model

    attribute :disability_action_type, String
    attribute :name, String
    attribute :classification_code, String
    attribute :service_relevance, String
    attribute :is_related_to_toxic_exposure, Bool
    attribute :exposure_or_event_or_injury, String
    attribute :rated_disability_id, String
    attribute :diagnostic_code, Integer
    attribute :secondary_disabilities, SecondaryDisability, array: true
  end

  class Center
    include Vets::Model

    attribute :name, String
    attribute :state, String
    attribute :city, String
  end

  class Treatment
    include Vets::Model

    attribute :treated_disability_names, String, array: true
    attribute :center, Center
    attribute :begin_date, String
  end

  class ServicePeriod
    include Vets::Model

    attribute :service_branch, String
    attribute :active_duty_begin_date, String
    attribute :active_duty_end_date, String
    attribute :service_component, String
    attribute :separation_location_code, String
  end

  class Confinement
    include Vets::Model

    attribute :approximate_begin_date, String
    attribute :approximate_end_date, String
  end

  class ObligationTermsOfService
    include Vets::Model

    attribute :begin_date, String
    attribute :end_date, String
  end

  # used to be "Title10Activation"
  class FederalActivation
    include Vets::Model

    attribute :anticipated_separation_date, String
    attribute :activation_date, String
  end

  class ReservesNationalGuardService
    include Vets::Model

    attribute :obligation_terms_of_service, ObligationTermsOfService
    attribute :unit_name, String
    attribute :unit_address, String
    attribute :component, String
    attribute :unit_phone, UnitPhone
    # "YES", "NO", or nil
    attribute :receiving_inactive_duty_training_pay, String
  end

  class SeparationSeverancePay
    include Vets::Model

    attribute :date_payment_received, String
    attribute :branch_of_service, String
    attribute :pre_tax_amount_received, Float
  end

  class MilitaryRetiredPay
    include Vets::Model

    attribute :branch_of_service, String
    attribute :monthly_amount, Float
  end

  class DirectDeposit
    include Vets::Model

    attribute :account_type, String
    attribute :account_number, String
    attribute :routing_number, String
    attribute :financial_institution_name, String
    attribute :no_account, Bool
  end

  class ServiceInformation
    include Vets::Model

    attribute :service_periods, ServicePeriod, array: true
    attribute :confinements, Confinement, array: true
    attribute :reserves_national_guard_service, ReservesNationalGuardService
    attribute :alternate_names, String, array: true
    attribute :served_in_active_combat_since911, Bool
    # used to be "Title10Activation"
    attribute :federal_activation, FederalActivation
  end

  class VeteranIdentification
    include Vets::Model

    attribute :current_va_employee, Bool
    attribute :mailing_address, MailingAddress
    attribute :service_number, String
    attribute :email_address, EmailAddress
    attribute :veteran_number, VeteranNumber
  end

  class CurrentlyHomeless
    include Vets::Model

    attribute :homeless_situation_options, String
    attribute :other_description, String
  end

  class RiskOfBecomingHomeless
    include Vets::Model

    attribute :living_situation_options, String
    attribute :other_description, String
  end

  class Homeless
    include Vets::Model

    attribute :point_of_contact, String
    attribute :point_of_contact_number, ContactNumber
    attribute :currently_homeless, CurrentlyHomeless
    attribute :risk_of_becoming_homeless, RiskOfBecomingHomeless
  end

  class ToxicExposure
    include Vets::Model

    attribute :gulf_war_hazard_service, GulfWarHazardService
    attribute :herbicide_hazard_service, HerbicideHazardService
    attribute :additional_hazard_exposures, AdditionalHazardExposures
    attribute :multiple_exposures, MultipleExposures, array: true
  end

  class ChangeOfAddress
    include Vets::Model

    attribute :dates, Dates
    attribute :type_of_address_change, String
    # rubocop:disable Naming/VariableNumber
    attribute :address_line_1, String
    attribute :address_line_2, String
    attribute :address_line_3, String
    # rubocop:enable Naming/VariableNumber
    attribute :city, String
    attribute :zip_first_five, String
    attribute :zip_last_four, String
    attribute :state, String
    attribute :country, String
    attribute :international_postal_code, String
  end

  class ServicePay
    include Vets::Model

    attribute :favor_training_pay, Bool
    attribute :favor_military_retired_pay, Bool
    # "YES", "NO", or nil
    attribute :receiving_military_retired_pay, String
    # "YES", "NO", or nil
    attribute :future_military_retired_pay, String
    attribute :future_military_retired_pay_explanation, String
    attribute :military_retired_pay, MilitaryRetiredPay
    attribute :retired_status, String
    attribute :received_separation_or_severance_pay, String
    attribute :separation_severance_pay, SeparationSeverancePay
  end

  class Form526
    include Vets::Model

    attribute :claimant_certification, Bool
    attribute :claim_process_type, String
    attribute :veteran_identification, VeteranIdentification
    attribute :change_of_address, ChangeOfAddress
    attribute :homeless, Homeless
    attribute :toxic_exposure, ToxicExposure
    attribute :disabilities, Disability, array: true
    attribute :treatments, Treatment, array: true
    attribute :service_information, ServiceInformation
    attribute :service_pay, ServicePay
    attribute :direct_deposit, DirectDeposit
    attribute :claim_notes, String
  end
end
