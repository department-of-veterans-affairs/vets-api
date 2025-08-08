# frozen_string_literal: true

require 'common/exceptions'
require 'brd/brd'
require 'bgs_service/standard_data_service'

module ClaimsApi
  module RevisedDisabilityCompensationValidations
    #
    # Any custom 526 submission validations above and beyond json schema validation
    #
    def validate_form_526_submission_values!
      # ensure 'claimDate', if provided, is a valid date not in the future
      validate_form_526_submission_claim_date!
      # ensure any provided 'separationLocationCode' values are valid EVSS ReferenceData values
      validate_form_526_location_codes!
    end

    def retrieve_separation_locations
      ClaimsApi::BRD.new.intake_sites
    rescue
      exception_msg = 'Failed To Obtain Intake Sites (Request Failed)'
      raise ::Common::Exceptions::ServiceUnavailable.new({ source: 'intake_sites', detail: exception_msg })
    end

    def validate_form_526_submission_claim_date!
      return if form_attributes['claimDate'].blank?
      return if DateTime.parse(form_attributes['claimDate']) <= Time.zone.now

      exception_msg = 'The request failed validation, because the claim date was in the future.'
      raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', exception_msg)
    end

    def validate_form_526_location_codes!
      # only retrieve separation locations if we'll need them
      need_locations = form_attributes['serviceInformation']['servicePeriods'].detect do |service_period|
        Date.parse(service_period['activeDutyEndDate']) > Time.zone.today
      end
      separation_locations = retrieve_separation_locations if need_locations

      form_attributes['serviceInformation']['servicePeriods'].each do |service_period|
        next if Date.parse(service_period['activeDutyEndDate']) <= Time.zone.today
        next if separation_locations.any? do |location|
                  location[:id]&.to_s == service_period['separationLocationCode']
                end

        exception_msg = "Provided separation location code is not valid: #{service_period['separationLocationCode']}"
        raise ::Common::Exceptions::InvalidFieldValue.new('Invalid separation location code',
                                                          exception_msg)
      end
    end
  end
end
