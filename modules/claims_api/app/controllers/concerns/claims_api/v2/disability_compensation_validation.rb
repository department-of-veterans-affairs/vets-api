# frozen_string_literal: false

require 'brd/brd'

module ClaimsApi
  module V2
    module DisabilityCompensationValidation
      def validate_form_526_submission_values!
        # ensure 'claimDate', if provided, is a valid date not in the future
        validate_form_526_submission_claim_date!
        # ensure 'claimantCertification' is true
        validate_form_526_claimant_certification!
        # ensure mailing address country is valid
        validate_form_526_current_mailing_address_country!
      end

      def validate_form_526_submission_claim_date!
        return if form_attributes['claimDate'].blank?
        # EVSS runs in the Central US Time Zone.
        # So 'claim_date' needs to be <= current day according to the Central US Time Zone.
        return if Date.parse(form_attributes['claimDate']) <= Time.find_zone!('Central Time (US & Canada)').today

        raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', form_attributes['claimDate'])
      end

      def validate_form_526_claimant_certification!
        return unless form_attributes['claimantCertification'] == false

        raise ::Common::Exceptions::InvalidFieldValue.new('claimantCertification',
                                                          form_attributes['claimantCertification'])
      end

      def validate_form_526_current_mailing_address_country!
        mailing_address = form_attributes.dig('veteranIdentification', 'mailingAddress')
        return if valid_countries.include?(mailing_address['country'])

        raise ::Common::Exceptions::InvalidFieldValue.new('country', mailing_address['country'])
      end

      def valid_countries
        @valid_countries ||= ClaimsApi::BRD.new(request).countries
      end
    end
  end
end
