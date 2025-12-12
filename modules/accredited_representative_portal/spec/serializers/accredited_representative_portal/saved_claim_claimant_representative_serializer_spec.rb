# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::SavedClaimClaimantRepresentativeSerializer, type: :serializer do
  subject { described_class.new(saved_claim_claimant_rep).serializable_hash }

  let(:saved_claim_claimant_rep) { create(:saved_claim_claimant_representative) }

  before do
    # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
    # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
    allow(FastImage).to receive(:size).and_wrap_original do |original, file|
      if file.respond_to?(:path) && file.path.end_with?('.pdf')
        nil
      else
        original.call(file)
      end
    end
  end

  describe '#first_name' do
    it 'returns first name' do
      expect(subject[:firstName]).to eq 'John'
    end
  end

  describe '#last_name' do
    it 'returns last name' do
      expect(subject[:lastName]).to eq 'Doe'
    end
  end

  describe '#confirmation_number' do
    it 'returns confirmation uuid' do
      uuid = saved_claim_claimant_rep.saved_claim.latest_submission_attempt.benefits_intake_uuid
      expect(subject[:confirmationNumber]).to eq uuid
    end
  end

  describe 'vbms_status' do
    context 'submission attempt is pending and over 10 days ago' do
      it 'returns awaiting_receipt_warning' do
        saved_claim_claimant_rep.saved_claim.latest_submission_attempt.update(aasm_state: 'pending')
        Timecop.freeze(10.days.from_now) do
          expect(subject[:vbmsStatus]).to eq 'awaiting_receipt_warning'
        end
      end
    end

    it 'returns vbms status' do
      expect(subject[:vbmsStatus]).to eq 'awaiting_receipt'
    end
  end
end
