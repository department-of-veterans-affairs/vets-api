# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/bgs_claim_status_mapper'

EVIDENCE_GATHERING = 'EVIDENCE_GATHERING_REVIEW_DECISION'

PHASE_TO_STATUS_MAPPINGS = {
  'claim received' => 'CLAIM_RECEIVED',
  'initial review' => 'INITIAL_REVIEW',
  'under review' => 'INITIAL_REVIEW',
  'pending' => 'PENDING',
  'evidence gathering' => EVIDENCE_GATHERING,
  'review of evidence' => EVIDENCE_GATHERING,
  'preparation for decision' => EVIDENCE_GATHERING,
  'pending decision approval' => EVIDENCE_GATHERING,
  'preparation for notification' => 'PREPARATION_FOR_NOTIFICATION',
  'errored' => 'ERRORED',
  'complete' => 'COMPLETE'
}.freeze

BGS_PHASE_TO_STATUS = {
  1 => 'Claim received',
  2 => 'Initial review',
  3 => 'Gathering of Evidence',
  4 => 'Review of Evidence',
  5 => 'Preparation for Decision',
  6 => 'Pending Decision Approval',
  7 => 'Preparation for notification',
  8 => 'Complete'
}.freeze

Rspec.describe ClaimsApi::BGSClaimStatusMapper do
  describe 'Phase to status mappings' do
    let(:claim_data) do
      {
        id: SecureRandom.uuid,
        status: 'pending',
        source: 'oddball',
        evss_id: nil
      }
    end

    PHASE_TO_STATUS_MAPPINGS.each do |key, value|
      context "when 'Phase type' is '#{key}'" do
        it "maps to '#{value}'" do
          claim_data[:status] = key
          mapped_value = ClaimsApi::BGSClaimStatusMapper.new(claim_data).name
          expect(mapped_value).to eq(value)
        end
      end
    end
  end

  describe 'BGS phase to status mapping' do
    let(:claim_data) do
      {
        id: SecureRandom.uuid,
        status: 'Under review',
        source: 'oddball',
        evss_id: nil,
        phase_number: 2
      }
    end

    context 'When phase number is supplied' do
      it 'maps to the correct phase name and status name' do
        mapped_value = ClaimsApi::BGSClaimStatusMapper.new(claim_data, claim_data[:phase_number]).name_from_phase
        expect(mapped_value).to eq('Initial review')
        mapped_name = ClaimsApi::BGSClaimStatusMapper.new(claim_data).name
        expect(mapped_name).to eq('INITIAL_REVIEW')
      end
    end
  end

  describe 'BGS phase to status mappings' do
    let(:claim_data) do
      {
        id: SecureRandom.uuid,
        status: 'pending',
        source: 'oddball',
        evss_id: nil
      }
    end

    BGS_PHASE_TO_STATUS.each do |key, value|
      context "when 'Phase number' is '#{key}'" do
        it "maps to '#{value}'" do
          claim_data[:phase_number] = key
          claim_data[:phase_type] = key
          mapped_value = ClaimsApi::BGSClaimStatusMapper.new(claim_data, key).name_from_phase
          expect(mapped_value).to eq(value)
        end
      end
    end
  end
end
