# frozen_string_literal: true

module Pensions
  ##
  # Extends FormMilitaryInformation to add additional military information fields to Pension prefill
  # @see app/models/form_profile.rb FormProfile::FormMilitaryInformation
  class FormMilitaryInformation < ::FormProfile::FormMilitaryInformation
    include Virtus.model

    attribute :first_uniformed_entry_date, String
    attribute :last_active_discharge_date, String
    attribute :service_branches_for_pensions, Hash
    attribute :service_number, String
  end
end
