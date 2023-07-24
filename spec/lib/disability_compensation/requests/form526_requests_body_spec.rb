# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/requests/form526_request_body'

Rspec.describe Requests do
  describe Requests::Form526 do
    let(:form) { Requests::Form526.new }

    it 'has claimant_certification attribute' do
      expect(form).to respond_to(:claimant_certification)
    end

    it 'has claim_process_type attribute' do
      expect(form).to respond_to(:claim_process_type)
    end

    it 'has claim_date attribute' do
      expect(form).to respond_to(:claim_date)
    end

    it 'has veteran_identification attribute' do
      expect(form).to respond_to(:veteran_identification)
    end

    it 'has change_of_address attribute' do
      expect(form).to respond_to(:change_of_address)
    end

    it 'has homeless attribute' do
      expect(form).to respond_to(:homeless)
    end

    it 'has toxic_exposure attribute' do
      expect(form).to respond_to(:toxic_exposure)
    end

    it 'has disabilities attribute' do
      expect(form).to respond_to(:disabilities)
    end

    it 'has treatments attribute' do
      expect(form).to respond_to(:treatments)
    end

    it 'has service_information attribute' do
      expect(form).to respond_to(:service_information)
    end

    it 'has service_pay attribute' do
      expect(form).to respond_to(:service_pay)
    end

    it 'has direct_deposit attribute' do
      expect(form).to respond_to(:direct_deposit)
    end
  end

  describe Requests::VeteranIdentification do
    let(:veteran) { Requests::VeteranIdentification.new }

    it 'has currently_va_employee attribute' do
      expect(veteran).to respond_to(:currently_va_employee)
    end

    it 'has mailing_address attribute' do
      expect(veteran).to respond_to(:mailing_address)
    end

    it 'has service_number attribute' do
      expect(veteran).to respond_to(:service_number)
    end

    it 'has email_address attribute' do
      expect(veteran).to respond_to(:email_address)
    end

    it 'has veteran_number attribute' do
      expect(veteran).to respond_to(:veteran_number)
    end

    it 'has va_file_number attribute' do
      expect(veteran).to respond_to(:va_file_number)
    end
  end

  describe Requests::MailingAddress do
    let(:address) { Requests::MailingAddress.new }

    it 'has number_and_street attribute' do
      expect(address).to respond_to(:number_and_street)
    end

    it 'has apartment_or_unit_number attribute' do
      expect(address).to respond_to(:apartment_or_unit_number)
    end

    it 'has city attribute' do
      expect(address).to respond_to(:city)
    end

    it 'has country attribute' do
      expect(address).to respond_to(:country)
    end

    it 'has zip_first_five attribute' do
      expect(address).to respond_to(:zip_first_five)
    end

    it 'has zip_last_four attribute' do
      expect(address).to respond_to(:zip_last_four)
    end

    it 'has state attribute' do
      expect(address).to respond_to(:state)
    end
  end

  describe Requests::EmailAddress do
    let(:email) { Requests::EmailAddress.new }

    it 'has email attribute' do
      expect(email).to respond_to(:email)
    end

    it 'has agree_to_email_related_to_claim attribute' do
      expect(email).to respond_to(:agree_to_email_related_to_claim)
    end
  end

  describe Requests::VeteranNumber do
    let(:veteran_number) { Requests::VeteranNumber.new }

    it 'has telephone attribute' do
      expect(veteran_number).to respond_to(:telephone)
    end

    it 'has international_telephone attribute' do
      expect(veteran_number).to respond_to(:international_telephone)
    end
  end

  describe Requests::GulfWarHazardService do
    let(:gulf_war_service) { Requests::GulfWarHazardService.new }

    it 'has served_in_gulf_war_hazard_locations attribute' do
      expect(gulf_war_service).to respond_to(:served_in_gulf_war_hazard_locations)
    end

    it 'has service_dates attribute' do
      expect(gulf_war_service).to respond_to(:service_dates)
    end
  end

  describe Requests::HerbicideHazardService do
    let(:herbicide_service) { Requests::HerbicideHazardService.new }

    it 'has served_in_herbicide_hazard_locations attribute' do
      expect(herbicide_service).to respond_to(:served_in_herbicide_hazard_locations)
    end

    it 'has other_locations_served attribute' do
      expect(herbicide_service).to respond_to(:other_locations_served)
    end

    it 'has service_dates attribute' do
      expect(herbicide_service).to respond_to(:service_dates)
    end
  end

  describe Requests::AdditionalHazardExposures do
    let(:additional_exposures) { Requests::AdditionalHazardExposures.new }

    it 'has additional_exposures attribute' do
      expect(additional_exposures).to respond_to(:additional_exposures)
    end

    it 'has specify_other_exposures attribute' do
      expect(additional_exposures).to respond_to(:specify_other_exposures)
    end

    it 'has exposure_dates attribute' do
      expect(additional_exposures).to respond_to(:exposure_dates)
    end
  end

  describe Requests::MultipleExposures do
    let(:multiple_exposures) { Requests::MultipleExposures.new }

    it 'has exposure_dates attribute' do
      expect(multiple_exposures).to respond_to(:exposure_dates)
    end

    it 'has exposure_location attribute' do
      expect(multiple_exposures).to respond_to(:exposure_location)
    end

    it 'has hazard_exposed_to attribute' do
      expect(multiple_exposures).to respond_to(:hazard_exposed_to)
    end
  end

  describe Requests::Disability do
    let(:disability) { Requests::Disability.new }

    it 'has disability_action_type attribute' do
      expect(disability).to respond_to(:disability_action_type)
    end

    it 'has name attribute' do
      expect(disability).to respond_to(:name)
    end

    it 'has classification_code attribute' do
      expect(disability).to respond_to(:classification_code)
    end

    it 'has service_relevance attribute' do
      expect(disability).to respond_to(:service_relevance)
    end

    it 'has approximate_date attribute' do
      expect(disability).to respond_to(:approximate_date)
    end

    it 'has is_related_to_toxic_exposure attribute' do
      expect(disability).to respond_to(:is_related_to_toxic_exposure)
    end

    it 'has exposure_or_event_or_injury attribute' do
      expect(disability).to respond_to(:exposure_or_event_or_injury)
    end

    it 'has rated_disability_id attribute' do
      expect(disability).to respond_to(:rated_disability_id)
    end

    it 'has diagnostic_code attribute' do
      expect(disability).to respond_to(:diagnostic_code)
    end

    it 'has secondary_disabilities attribute' do
      expect(disability).to respond_to(:secondary_disabilities)
    end
  end

  describe Requests::Center do
    let(:center) { Requests::Center.new }

    it 'has name attribute' do
      expect(center).to respond_to(:name)
    end

    it 'has state attribute' do
      expect(center).to respond_to(:state)
    end

    it 'has city attribute' do
      expect(center).to respond_to(:city)
    end
  end

  describe Requests::Treatment do
    let(:treatment) { Requests::Treatment.new }

    it 'has treated_disability_names attribute' do
      expect(treatment).to respond_to(:treated_disability_names)
    end

    it 'has center attribute' do
      expect(treatment).to respond_to(:center)
    end

    it 'has begin_date attribute' do
      expect(treatment).to respond_to(:begin_date)
    end
  end

  describe Requests::ServicePeriod do
    let(:service_period) { Requests::ServicePeriod.new }

    it 'has service_branch attribute' do
      expect(service_period).to respond_to(:service_branch)
    end

    it 'has active_duty_begin_date attribute' do
      expect(service_period).to respond_to(:active_duty_begin_date)
    end

    it 'has active_duty_end_date attribute' do
      expect(service_period).to respond_to(:active_duty_end_date)
    end

    it 'has service_component attribute' do
      expect(service_period).to respond_to(:service_component)
    end

    it 'has separation_location_code attribute' do
      expect(service_period).to respond_to(:separation_location_code)
    end
  end

  describe Requests::Confinement do
    let(:confinement) { Requests::Confinement.new }

    it 'has approximate_begin_date attribute' do
      expect(confinement).to respond_to(:approximate_begin_date)
    end

    it 'has approximate_end_date attribute' do
      expect(confinement).to respond_to(:approximate_end_date)
    end
  end

  describe Requests::ObligationTermsOfService do
    let(:obligation_terms) { Requests::ObligationTermsOfService.new }

    it 'has begin_date attribute' do
      expect(obligation_terms).to respond_to(:begin_date)
    end

    it 'has end_date attribute' do
      expect(obligation_terms).to respond_to(:end_date)
    end
  end

  describe Requests::Title10Activation do
    let(:title10_activation) { Requests::Title10Activation.new }

    it 'has anticipated_separation_date attribute' do
      expect(title10_activation).to respond_to(:anticipated_separation_date)
    end

    it 'has title10_activation_date attribute' do
      expect(title10_activation).to respond_to(:title10_activation_date)
    end
  end

  describe Requests::ReservesNationalGuardService do
    let(:reserves_service) { Requests::ReservesNationalGuardService.new }

    it 'has obligation_terms_of_service attribute' do
      expect(reserves_service).to respond_to(:obligation_terms_of_service)
    end

    it 'has unit_name attribute' do
      expect(reserves_service).to respond_to(:unit_name)
    end

    it 'has unit_address attribute' do
      expect(reserves_service).to respond_to(:unit_address)
    end

    it 'has component attribute' do
      expect(reserves_service).to respond_to(:component)
    end

    it 'has title10_activation attribute' do
      expect(reserves_service).to respond_to(:title10_activation)
    end

    it 'has unit_phone attribute' do
      expect(reserves_service).to respond_to(:unit_phone)
    end

    it 'has receiving_inactive_duty_training_pay attribute' do
      expect(reserves_service).to respond_to(:receiving_inactive_duty_training_pay)
    end
  end

  describe Requests::SeparationSeverancePay do
    let(:separation_pay) { Requests::SeparationSeverancePay.new }

    it 'has date_payment_received attribute' do
      expect(separation_pay).to respond_to(:date_payment_received)
    end

    it 'has branch_of_service attribute' do
      expect(separation_pay).to respond_to(:branch_of_service)
    end

    it 'has pre_tax_amount_received attribute' do
      expect(separation_pay).to respond_to(:pre_tax_amount_received)
    end
  end

  describe Requests::MilitaryRetiredPay do
    let(:military_retired_pay) { Requests::MilitaryRetiredPay.new }

    it 'has branch_of_service attribute' do
      expect(military_retired_pay).to respond_to(:branch_of_service)
    end

    it 'has monthly_amount attribute' do
      expect(military_retired_pay).to respond_to(:monthly_amount)
    end
  end

  describe Requests::DirectDeposit do
    let(:direct_deposit) { Requests::DirectDeposit.new }

    it 'has account_type attribute' do
      expect(direct_deposit).to respond_to(:account_type)
    end

    it 'has account_number attribute' do
      expect(direct_deposit).to respond_to(:account_number)
    end

    it 'has routing_number attribute' do
      expect(direct_deposit).to respond_to(:routing_number)
    end

    it 'has financial_institution_name attribute' do
      expect(direct_deposit).to respond_to(:financial_institution_name)
    end

    it 'has no_account attribute' do
      expect(direct_deposit).to respond_to(:no_account)
    end
  end
end
