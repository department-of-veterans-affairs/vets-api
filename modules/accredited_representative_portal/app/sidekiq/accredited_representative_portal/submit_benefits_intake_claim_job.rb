# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SubmitBenefitsIntakeClaimJob < Lighthouse::SubmitBenefitsIntakeClaim
    def generate_metadata
      veteran = @claim.parsed_form['veteran']

      ::BenefitsIntake::Metadata.generate(
        veteran.dig('name', 'first'),
        veteran.dig('name', 'last'),
        veteran['ssn'],
        veteran['postalCode'],
        "#{@claim.class} va.gov",
        @claim.form_id,
        @claim.business_line
      )
    end

    def stamp_pdf(record)
      case record
      when PersistentAttachments::VAFormDocumentation
        ##
        # TODO: Our documentation attachments probably have some other stamping
        # requirements than what the parent class does.
        #
        super
      when SavedClaim::BenefitsIntake
        record.to_pdf.tap do |stamped_template_path|
          ##
          # TODO: Reimplement PDF stamping with our own code. `SimpleFormsApi`'s
          # abstraction stamps the PDF, but it also fills out forms, which we may
          # not need.
          #
          SimpleFormsApi::PdfStamper.new(
            form: SimpleFormsApi::VBA21686C.new({}),
            stamped_template_path:,
            current_loa: SignIn::Constants::Auth::LOA3,
            timestamp: @claim.created_at
          ).stamp_pdf
        end
      else
        raise ArgumentError
      end
    end
  end
end
