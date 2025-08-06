# frozen_string_literal: true

require 'common/exceptions'
require 'brd/brd'
require 'bgs_service/standard_data_service'

module ClaimsApi
  module AltDisabilityCompensationValidations # rubocop:disable Metrics/ModuleLength
    #
    # Any custom 526 submission validations above and beyond json schema validation
    #
    def validate_form_526_submission_values!
      # ensure 'claimDate', if provided, is a valid date not in the future
      validate_form_526_submission_claim_date!
    end

    private

    def validate_form_526_submission_claim_date!
      return if form_attributes['claimDate'].blank?
      return if DateTime.parse(form_attributes['claimDate']) <= Time.zone.now

      raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', form_attributes['claimDate'])
    end
  end
end
