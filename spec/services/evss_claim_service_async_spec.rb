# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimServiceAsync do
  subject { described_class.new(user) }

  let(:user) { create(:user, :loa3) }
  let(:tracker) { EVSSClaimsSyncStatusTracker.find_or_build(user.uuid) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }

  describe '#all' do
    context 'there is not an existing tracker staus' do
      it 'creates a background job' do
        expect(EVSS::RetrieveClaimsFromRemoteJob).to receive(:perform_async).with(user.uuid)
        subject.all
      end

      it "sets status to 'REQUESETED'" do
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to receive(:set_collection_status).with('REQUESTED')
        subject.all
      end

      it 'returns an empty array' do
        expect(subject.all).to eq([[], 'REQUESTED'])
      end
    end

    %w[SUCCESS FAILED].each do |result|
      context "there is a '#{result}' tracker entry" do
        before do
          claim
          tracker.set_collection_status(result)
        end

        it 'returns an array of claims' do
          expect(subject.all).to eq([[claim], result])
        end

        it 'deletes the existing tracker entry' do
          expect(tracker.get_collection_status).to eq result
          subject.all
          tracker = EVSSClaimsSyncStatusTracker.find(user.uuid)
          expect(tracker.get_collection_status).to be_nil
        end
      end
    end
  end

  describe '#update_from_remote' do
    context 'there is not an existing tracker staus' do
      it 'creates a background job' do
        expect(EVSS::UpdateClaimFromRemoteJob).to receive(:perform_async).with(user.uuid, claim.id)
        subject.update_from_remote(claim)
      end

      it "sets status to 'REQUESETED'" do
        expect_any_instance_of(EVSSClaimsSyncStatusTracker).to receive(:set_single_status).with('REQUESTED')
        subject.update_from_remote(claim)
      end

      it 'returns the claim' do
        expect(subject.update_from_remote(claim)).to eq([claim, 'REQUESTED'])
      end
    end

    %w[SUCCESS FAILED].each do |result|
      context "there is a '#{result}' tracker entry" do
        before do
          tracker.claim_id = claim.id
          tracker.set_single_status(result)
        end

        it 'returns an array of claims' do
          expect(subject.update_from_remote(claim)).to eq([claim, result])
        end

        it 'deletes the existing tracker entry' do
          expect(tracker.get_single_status).to eq result
          subject.update_from_remote(claim)
          tracker = EVSSClaimsSyncStatusTracker.find(user.uuid)
          tracker.claim_id = claim.id
          expect(tracker.get_single_status).to be_nil
        end
      end
    end
  end
end
