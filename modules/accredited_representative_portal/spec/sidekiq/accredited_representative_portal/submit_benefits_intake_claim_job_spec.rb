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

  subject(:perform) { described_class.new.perform(claim.id) }

  let(:claim) do
    attachments = [
      create(:persistent_attachment_va_form),
      create(:persistent_attachment_va_form_documentation)
    ]

    AccreditedRepresentativePortal::SavedClaimService::Create.perform(
      type: AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim,
      attachment_guids: attachments.map(&:guid),
      metadata: dependent_claimant_form
    )
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

  it 'performs' do
    vcr_options = {
      ##
      # It seems as though request bodies and headers are dynamic given static
      # inputs, which is why we exclude them from VCR matching.
      #
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

    use_cassette('performs', vcr_options) do
      expect_any_instance_of(BenefitsIntakeService::Service).to(
        receive(:upload_doc).and_call_original
      )

      expect { perform }.to change {
        FormSubmissionAttempt.where.not(benefits_intake_uuid: nil).count
      }.by(1)
    end
  end
end
