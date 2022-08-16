# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::SubmissionJob do
  let(:claim) do
    require 'saved_claim/caregivers_assistance_claim'

    create(:caregivers_assistance_claim)
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when claim cant be destroyed' do
      it 'logs the exception to sentry' do
        expect_any_instance_of(Form1010cg::Service).to receive(:process_claim_v2!)
        error = StandardError.new
        expect_any_instance_of(SavedClaim::CaregiversAssistanceClaim).to receive(:destroy!).and_raise(error)

        expect(job).to receive(:log_exception_to_sentry).with(error)
        job.perform(claim.id)
      end
    end

    it 'calls process_claim_v2!' do
      expect_any_instance_of(Form1010cg::Service).to receive(:process_claim_v2!)

      job.perform(claim.id)

      expect(SavedClaim::CaregiversAssistanceClaim.exists?(id: claim.id)).to eq(false)
    end
  end
end
