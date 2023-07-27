# frozen_string_literal: true

require 'active_model'
require 'virtus'

module Requests
  class Dates
    include ActiveModel::Serialization
    include Virtus.model

    attribute :begin_date, Date
    attribute :end_date, Date
  end

  class ContactNumber
    include Virtus.model
    include ActiveModel::Serialization

    attribute :telephone, String
    attribute :international_telephone, String
  end

  class MailingAddress
    include Virtus.model
    include ActiveModel::Serialization

    attribute :number_and_street, String
    attribute :apartment_or_unit_number, String
    attribute :city, String
    attribute :country, String
    attribute :zip_first_five, String
    attribute :zip_last_four, String
    attribute :state, String
  end

  class EmailAddress
    include Virtus.model
    include ActiveModel::Serialization

    attribute :email, String
    attribute :agree_to_email_related_to_claim, Boolean
  end

  class VeteranNumber
    include Virtus.model
    include ActiveModel::Serialization

    attribute :telephone, String
    attribute :international_telephone, String
  end

  class GulfWarHazardService
    include Virtus.model
    include ActiveModel::Serialization

    attribute :served_in_gulf_war_hazard_locations, Boolean
    attribute :service_dates, Dates
  end

  class HerbicideHazardService
    include Virtus.model
    include ActiveModel::Serialization

    attribute :served_in_herbicide_hazard_locations, Boolean
    attribute :other_locations_served, String
    attribute :service_dates, Dates
  end

  class AdditionalHazardExposures
    include Virtus.model
    include ActiveModel::Serialization

    attribute :additional_exposures, Array[String]
    attribute :specify_other_exposures, String
    attribute :exposure_dates, Dates
  end

  class MultipleExposures
    include Virtus.model
    include ActiveModel::Serialization

    attribute :exposure_dates, Dates
    attribute :exposure_location, String
    attribute :hazard_exposed_to, String
  end

  class SecondaryDisability
    include Virtus.model
    include ActiveModel::Serialization

    attribute :name, String
    attribute :disability_action_type, String
    attribute :classification_code, String
    attribute :service_relevance, String
    attribute :approximate_date, String
  end

  class Disability
    include Virtus.model
    include ActiveModel::Serialization

    attribute :disability_action_type, String
    attribute :name, String
    attribute :classification_code, String
    attribute :service_relevance, String
    attribute :approximate_date, String
    attribute :is_related_to_toxic_exposure, Boolean
    attribute :exposure_or_event_or_injury, String
    attribute :rated_disability_id, String
    attribute :diagnostic_code, Integer
    attribute :secondary_disabilities, Array[SecondaryDisability]
  end

  class Center
    include Virtus.model
    include ActiveModel::Serialization

    attribute :name, String
    attribute :state, String
    attribute :city, String
  end

  class Treatment
    include Virtus.model
    include ActiveModel::Serialization

    attribute :treated_disability_names, Array[String]
    attribute :center, Center
    attribute :begin_date, String
  end

  class ServicePeriod
    include Virtus.model
    include ActiveModel::Serialization

    attribute :service_branch, String
    attribute :active_duty_begin_date, Date
    attribute :active_duty_end_date, Date
    attribute :service_component, String
    attribute :separation_location_code, String
  end

  class Confinement
    include Virtus.model
    include ActiveModel::Serialization

    attribute :approximate_begin_date, String
    attribute :approximate_end_date, String
  end

  class ObligationTermsOfService
    include Virtus.model
    include ActiveModel::Serialization

    attribute :begin_date, Date
    attribute :end_date, Date
  end

  class Title10Activation
    include Virtus.model
    include ActiveModel::Serialization

    attribute :anticipated_separation_date, Date
    attribute :title10_activation_date, Date
  end

  class ReservesNationalGuardService
    include Virtus.model
    include ActiveModel::Serialization

    attribute :obligation_terms_of_service, ObligationTermsOfService
    attribute :unit_name, String
    attribute :unit_address, String
    attribute :component, String
    attribute :title10_activation, Title10Activation
    attribute :unit_phone, ContactNumber
    attribute :receiving_inactive_duty_training_pay, Boolean
  end

  class SeparationSeverancePay
    include Virtus.model
    include ActiveModel::Serialization

    attribute :date_payment_received, String
    attribute :branch_of_service, String
    attribute :pre_tax_amount_received, Float
  end

  class MilitaryRetiredPay
    include Virtus.model
    include ActiveModel::Serialization

    attribute :branch_of_service, String
    attribute :monthly_amount, Float
  end

  class DirectDeposit
    include Virtus.model
    include ActiveModel::Serialization

    attribute :account_type, String
    attribute :account_number, String
    attribute :routing_number, String
    attribute :financial_institution_name, String
    attribute :no_account, Boolean
  end

  class ServiceInformation
    include Virtus.model
    include ActiveModel::Serialization

    attribute :service_periods, Array[ServicePeriod]
    attribute :confinements, Array[Confinement]
    attribute :reserves_national_guard_service, ReservesNationalGuardService
    attribute :alternate_names, Array[String]
    attribute :served_in_active_combat_since911, Boolean
  end

  class VeteranIdentification
    include Virtus.model
    include ActiveModel::Serialization

    attribute :currently_va_employee, Boolean
    attribute :mailing_address, MailingAddress
    attribute :service_number, String
    attribute :email_address, EmailAddress
    attribute :veteran_number, VeteranNumber
    attribute :va_file_number, String
  end

  class CurrentlyHomeless
    include Virtus.model
    include ActiveModel::Serialization

    attribute :homeless_situation_options, String
    attribute :other_description, String
  end

  class RiskOfBecomingHomeless
    include Virtus.model
    include ActiveModel::Serialization

    attribute :living_situation_options, String
    attribute :other_description, String
  end

  class Homeless
    include Virtus.model
    include ActiveModel::Serialization

    attribute :point_of_contact, String
    attribute :point_of_contact_number, ContactNumber
    attribute :currently_homeless, CurrentlyHomeless
    attribute :risk_of_becoming_homeless, RiskOfBecomingHomeless
  end

  class ToxicExposure
    include Virtus.model
    include ActiveModel::Serialization

    attribute :gulf_war_hazard_service, GulfWarHazardService
    attribute :herbicide_hazard_service, HerbicideHazardService
    attribute :additional_hazard_exposures, AdditionalHazardExposures
    attribute :multiple_exposures, MultipleExposures
  end

  class ChangeOfAddress
    include Virtus.model
    include ActiveModel::Serialization

    attribute :dates, Dates
    attribute :type_of_address_change, String
    attribute :number_and_street, String
    attribute :apartment_or_unit_number, String
    attribute :city, String
    attribute :zip_first_five, String
    attribute :zip_last_four, String
    attribute :state, String
    attribute :country, String
  end

  class ServicePay
    include Virtus.model
    include ActiveModel::Serialization

    attribute :favor_training_pay, Boolean
    attribute :favor_military_retired_pay, Boolean
    attribute :receiving_military_retired_pay, Boolean
    attribute :future_military_retired_pay, Boolean
    attribute :future_military_retired_pay_explanation, String
    attribute :military_retired_pay, MilitaryRetiredPay
    attribute :retired_status, String
    attribute :received_separation_or_severance_pay, Boolean
    attribute :separation_severance_pay, SeparationSeverancePay
  end

  class Form526
    include Virtus.model
    include ActiveModel::Serialization

    attribute :claimant_certification, Boolean
    attribute :claim_process_type, String
    attribute :claim_date, Date
    attribute :veteran_identification, VeteranIdentification
    attribute :change_of_address, ChangeOfAddress
    attribute :homeless, Homeless
    attribute :toxic_exposure, ToxicExposure
    attribute :disabilities, Array[Disability]
    attribute :treatments, Array[Treatment]
    attribute :service_information, ServiceInformation
    attribute :service_pay, ServicePay
    attribute :direct_deposit, DirectDeposit
  end
end
