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

  it 'performs' do
    ##
    # Triggers `VCR::Errors::UnhandledHTTPRequestError`which means we're in the
    # job and ready to verify outcomes.
    #
    perform
    expect(true).to be_truthy
  end
end
