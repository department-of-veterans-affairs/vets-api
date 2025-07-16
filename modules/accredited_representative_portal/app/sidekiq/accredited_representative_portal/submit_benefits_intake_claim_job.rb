# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SubmitBenefitsIntakeClaimJob < Lighthouse::SubmitBenefitsIntakeClaim
    ##
    # TODO: Remove this parent class override.
    #
    # This is a temporary workaround while there is configuration inconsistency
    # between two Benefits Intake API Ruby clients in `vets-api`'s staging
    # environment. The inconsistency between these Ruby clients matters because
    # we use both of them in different parts of claims' lifecycles:
    #
    # - `BenefitsIntakeService::Service`
    #   - Points to Lighthouse's staging environment
    #   - Used to submit claims initially
    # - `BenefitsIntake::Service`
    #   - Points to Lighthouse's sandbox environment
    #   - Used to check claims' statuses afterwards
    #
    def init(saved_claim_id)
      @claim =
        ::SavedClaim.find(saved_claim_id)

      @lighthouse_service =
        ##
        # Rather than:
        # ```
        # BenefitsIntakeService::Service.new(with_upload_location: true)
        # ```
        #
        BenefitsIntakeService::Service.new.tap do |service|
          service.define_singleton_method(:config) do
            BenefitsIntake::Service.configuration
          end

          upload = service.get_location_and_uuid
          service.instance_variable_set(:@uuid, upload[:uuid])
          service.instance_variable_set(:@location, upload[:location])
        end
    end

    ##
    # Overrides parent class.
    #
    def generate_metadata
      veteran = @claim.parsed_form['veteran']
      veteran_name = veteran['name']

      ::BenefitsIntake::Metadata.generate(
        veteran_name['first'],
        veteran_name['last'],
        veteran['ssn'],
        veteran['postalCode'],
        "#{@claim.class} va.gov",
        @claim.class::PROPER_FORM_ID,
        @claim.class::BUSINESS_LINE
      )
    end

    def get_auth_text_stamp
      timestamp = Time.current
      current_time = "#{timestamp.utc.strftime('%H:%M:%S  %Y-%m-%d %I:%M %p')} UTC"
      "Submitted via VA.gov at #{current_time}. Signed in and submitted with an identity-verified account."
    end

    ##
    # Overrides parent class.
    #
    def stamp_pdf(record)
      case record
      when PersistentAttachments::VAFormDocumentation
        pdf_path = record.to_pdf
        PDFUtilities::DatestampPdf.new(pdf_path).run(
          text: get_auth_text_stamp, x: 5, y: 5, text_only: true
        )
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
