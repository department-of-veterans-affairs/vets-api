# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SubmitBenefitsIntakeClaimJob < Lighthouse::SubmitBenefitsIntakeClaim
    def generate_metadata
      veteran = @claim.parsed_form['veteran']

      ::BenefitsIntake::Metadata.generate(
        veteran.dig('name', 'first'),
        veteran.dig('name', 'last'),
        veteran['vaFileNumber'] || veteran['ssn'],
        veteran.dig('address', 'zipCode'),
        "#{@claim.class} va.gov",
        @claim.form_id,
        @claim.business_line
      )
    end
  end
end
