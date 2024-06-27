# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StructuredData::ProcessDataJob, :uploader_helpers do
  stub_virus_scan
  let(:pension_burial) { create(:pension_burial) }
  let(:claim) { pension_burial.saved_claim }
  let(:job) { StructuredData::ProcessDataJob.new }

  describe '#perform' do
    let(:bip_claims) { instance_double(BipClaims::Service) }

    before do
      allow_any_instance_of(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform)
      allow(BipClaims::Service).to receive(:new).and_return(bip_claims)
      allow(bip_claims).to receive(:lookup_veteran_from_mpi).and_return(
        OpenStruct.new(participant_id: 123)
      )
    end

    it 'attempts Veteran MVI lookup' do
      expect(bip_claims).to receive(:lookup_veteran_from_mpi).with(claim).and_return(
        OpenStruct.new(participant_id: 123)
      )
      job.perform(claim.id)
    end

    it 'calls Benefits Intake processing job' do
      expect_any_instance_of(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform)
      job.perform(claim.id)
    end

    it 'increments metric for successful claim submission to va.gov' do
      expect(StatsD).to receive(:increment).at_least(:once)
      job.perform(claim.id)
    end

    it 'sends a confirmation email' do
      expect(job).to receive(:send_confirmation_email)
      job.perform(claim.id)
    end
  end

  describe '#send_confirmation_email' do
    it 'calls the VA notify email job' do
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        'foo@foo.com',
        'burial_claim_confirmation_email_template_id',
        {
          'form_name' => 'Burial Benefit Claim (Form 21P-530)',
          'confirmation_number' => claim.guid,
          'deceased_veteran_first_name_last_initial' => 'WESLEY F.',
          'benefits_claimed' => " - Burial Allowance \n - Plot Allowance \n - Transportation",
          'facility_name' => 'Attention:  St. Paul Pension Center',
          'street_address' => 'P.O. Box 5365',
          'city_state_zip' => 'Janesville, WI 53547-5365',
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'first_name' => 'DERRICK'
        }
      )

      job.instance_variable_set(:@claim, claim)
      job.send_confirmation_email
    end
  end
end
