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

    def validate_service_periods_present!
      service_periods = form_attributes.dig('serviceInformation', 'servicePeriods')
      if service_periods.nil?
        raise ::Common::Exceptions::UnprocessableEntity.new({ detail: 'List of service periods must be provided' })
      end
    end

    def validate_service_periods_quantity!
      service_periods = form_attributes.dig('serviceInformation', 'servicePeriods')
      sp_size = service_periods.size
      if sp_size < 1 || sp_size > 100
        raise ::Common::Exceptions::InvalidFieldValue.new('serviceInformation.servicePeriods',
                                                          "Number of service periods #{sp_size} \
                                                          must be between 1 and 100 inclusive")
      end
    end

    def validate_service_periods_chronology!
      form_attributes.dig('serviceInformation', 'servicePeriods')
      form_attributes['serviceInformation']['servicePeriods'].each do |service_period|
        begin_date = service_period['activeDutyBeginDate']
        end_date = service_period['activeDutyEndDate']
        next if end_date.blank?

        if Date.parse(end_date) < Date.parse(begin_date)
          raise ::Common::Exceptions::InvalidFieldValue.new('serviceInformation.servicePeriods',
                                                            "Invalid service period duty dates - \
                                                            Provided service period duty dates are \
                                                            out of order: begin=#{begin_date} end=#{end_date}")
        end
      end
    end

    def validate_form_526_no_active_duty_end_date_more_than_180_days_in_future!
      service_periods = form_attributes.dig('serviceInformation', 'servicePeriods')

      end_date_180_days_in_future = service_periods.find do |sp|
        active_duty_end_date = sp['activeDutyEndDate']
        next if active_duty_end_date.blank?

        Date.parse(active_duty_end_date) > 180.days.from_now.end_of_day
      end

      unless end_date_180_days_in_future.nil?
        raise ::Common::Exceptions::InvalidFieldValue.new(
          'serviceInformation/servicePeriods/activeDutyEndDate',
          "Provided service period duty end date is more than 180 days in the future: \
          #{end_date_180_days_in_future['activeDutyEndDate']}"
        )
      end
    end
  end
end
