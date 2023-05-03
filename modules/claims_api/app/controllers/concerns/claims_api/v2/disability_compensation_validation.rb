# frozen_string_literal: false

module ClaimsApi
  module V2
    module DisabilityCompensationValidation
      def validate_form_526_submission_values!
        # ensure 'claimDate', if provided, is a valid date not in the future
        validate_form_526_submission_claim_date!
        # ensure 'claimantCertification' is true
        validate_form_526_claimant_certification!
      end

      def validate_form_526_submission_claim_date!
        return if form_attributes['claimDate'].blank?
        return if DateTime.parse(form_attributes['claimDate']) <= Time.zone.now

        raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', form_attributes['claimDate'])
      end

      def validate_form_526_claimant_certification!
        return unless form_attributes['claimantCertification'] == false

        raise ::Common::Exceptions::InvalidFieldValue.new('claimantCertification',
                                                          form_attributes['claimantCertification'])
      end
    end
  end
end
