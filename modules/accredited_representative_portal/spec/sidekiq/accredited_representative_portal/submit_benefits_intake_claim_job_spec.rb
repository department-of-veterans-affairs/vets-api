# frozen_string_literal: true

require 'rails_helper'
require AccreditedRepresentativePortal::Engine.root / 'spec/spec_helper'

RSpec.describe AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob do
  fixture_path =
    'form_data/saved_claim/benefits_intake/dependent_claimant.json'

  dependent_claimant_form =
    load_fixture(fixture_path) do |fixture|
      JSON.parse(fixture)
    end

  subject(:perform) do
    attachments = [
      create(:persistent_attachment_va_form, form_id: '21-686c'),
      create(:persistent_attachment_va_form_documentation, form_id: '21-686c')
    ]

    AccreditedRepresentativePortal::SavedClaimService::Create.perform(
      type: AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim,
      attachment_guids: attachments.map(&:guid),
      metadata: dependent_claimant_form,
      claimant_representative:
        AccreditedRepresentativePortal::ClaimantRepresentative.new(
          claimant_id: '1234',
          accredited_individual_registration_number: '10001',
          power_of_attorney_holder:
            AccreditedRepresentativePortal::PowerOfAttorneyHolder.new(
              type: 'veteran_service_organization', poa_code: '123',
              name: 'Org Name', can_accept_digital_poa_requests: nil
            )
        )
    )
  end

  let(:vcr_options) do
    ##
    # It seems as though request bodies and headers are dynamic given static
    # inputs, which is why we exclude them from VCR matching.
    #
    {
      match_requests_on: %i[method uri],

      ##
      # This job is behaving incorrectly if it does not perform all of the
      # requests to Benefits Intake API that were recorded in the cassette.
      # Those are:
      #   - `POST /uploads` (gets an <upload_location>)
      #   - `POST /uploads/validate_document` (validates 1st document)
      #   - `POST /uploads/validate_document` (validates 2nd document)
      #   - `PUT <upload_location>` (submits the document)
      #
      allow_unused_http_interactions: false
    }
  end

  before do
    ##
    # This works around some test configuration weirdness. Without this, the
    # locations used for reading and writing differ, likely due to a difference
    # in which Shrine plugins have been plugged in at various points.
    #
    allow_any_instance_of(Shrine::UploadedFile).to(
      receive(:storage).and_return(Shrine.storages[:store])
    )
  end

  after do
    # Clean up mocks to prevent test pollution in parallel runs
    RSpec::Mocks.space.reset_all
  end

  context 'accredited_representative_portal_lighthouse_api_key is not set' do
    before do
      allow(Flipper).to receive(:enabled?).with(
        :accredited_representative_portal_lighthouse_api_key
      ).and_return(false)
    end

    it 'performs using BenefitsIntakeService::Service' do
      use_cassette('performs', vcr_options) do
        expect_any_instance_of(BenefitsIntakeService::Service).to(
          receive(:upload_doc).and_call_original
        )

        expect { perform }.to change {
          FormSubmissionAttempt.where.not(benefits_intake_uuid: nil).count
        }.by(1)
      end
    end

    context 'submission has additional documentation' do
      around { |example| Timecop.freeze { example.run } }

      let(:stamper) { double }

      it 'stamps the footer of the additional docs' do
        timestamp = DateTime.now.utc.strftime('%H:%M:%S  %Y-%m-%d %I:%M %p')

        use_cassette('performs', vcr_options) do
          # mock stamping of provided VA form
          allow(SimpleFormsApi::PdfStamper).to receive(:new).and_return(stamper)
          allow(stamper).to receive(:stamp_pdf)

          expect_any_instance_of(PDFUtilities::DatestampPdf).to receive(:run).with(
            text: "Submitted via VA.gov at #{timestamp} UTC. Signed in and submitted " \
                  'with an identity-verified account.',
            text_only: true, x: 5, y: 5
          ).and_call_original

          perform
        end
      end
    end
  end

  context 'accredited_representative_portal_lighthouse_api_key is set' do
    before do
      allow(Flipper).to receive(:enabled?).with(
        :accredited_representative_portal_lighthouse_api_key
      ).and_return(true)

      # Mock the API key configuration that BenefitsIntakeService requires
      allow(Settings.accredited_representative_portal.lighthouse.benefits_intake).to(
        receive(:api_key).and_return('test-api-key')
      )
    end

    it 'performs using ARP BenefitsIntakeService' do
      use_cassette('performs', vcr_options) do
        expect_any_instance_of(AccreditedRepresentativePortal::BenefitsIntakeService).to(
          receive(:upload_doc).and_call_original
        )

        expect { perform }.to change {
          FormSubmissionAttempt.where.not(benefits_intake_uuid: nil).count
        }.by(1)
      end
    end

    context 'submission has additional documentation' do
      around { |example| Timecop.freeze { example.run } }

      let(:stamper) { double }

      it 'stamps the footer of the additional docs' do
        timestamp = DateTime.now.utc.strftime('%H:%M:%S  %Y-%m-%d %I:%M %p')

        use_cassette('performs', vcr_options) do
          # mock stamping of provided VA form
          allow(SimpleFormsApi::PdfStamper).to receive(:new).and_return(stamper)
          allow(stamper).to receive(:stamp_pdf)

          expect_any_instance_of(PDFUtilities::DatestampPdf).to receive(:run).with(
            text: "Submitted via VA.gov at #{timestamp} UTC. Signed in and submitted " \
                  'with an identity-verified account.',
            text_only: true, x: 5, y: 5
          ).and_call_original

          perform
        end
      end
    end
  end
end
