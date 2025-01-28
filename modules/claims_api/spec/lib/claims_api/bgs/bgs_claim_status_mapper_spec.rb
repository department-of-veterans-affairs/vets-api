# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/bgs_claim_status_mapper'

Rspec.describe ClaimsApi::BGSClaimStatusMapper do
  describe 'Phase to status mappings' do
    let(:claim_one) { { id: SecureRandom.uuid, status: 'pend' } }
    let(:claim_two) { { id: SecureRandom.uuid, status: 'can' } }
    let(:claim_three) { { id: SecureRandom.uuid, status: 'pending' } }
    let(:claim_four) { { id: SecureRandom.uuid, status: 'initial review', phase_number: 2 } }
    let(:claim_five) { { id: SecureRandom.uuid, status: 'complete', phase_number: 8 } }
    let(:claim_six) { { id: SecureRandom.uuid, status: 'review of evidence', phase_number: 4 } }
    let(:claim_seven) { { id: SecureRandom.uuid, status: 'preparation for decision', phase_number: 5 } }
    let(:claim_eight) { { id: SecureRandom.uuid, status: 'comp', phase_number: 8 } }
    let(:claim_nine) { { id: SecureRandom.uuid, status: 'claim received', phase_number: 1 } }
    let(:claim_ten) { { id: SecureRandom.uuid, status: 'gathering of evidence', phase_number: 3 } }
    let(:claim_eleven) { { id: SecureRandom.uuid, status: 'evidence gathering', phase_number: 3 } }
    let(:claim_twelve) { { id: SecureRandom.uuid, status: 'rfd', phase_number: 5 } }
    let(:claim_thirteen) { { id: SecureRandom.uuid, status: 'pending decision approval', phase_number: 6 } }
    let(:claim_fourteen) { { id: SecureRandom.uuid, status: 'preparation for notification', phase_number: 7 } }
    let(:claim_fifthteen) { { id: SecureRandom.uuid, status: 'prep', phase_number: 7 } }
    let(:claim_sixteen) { { id: SecureRandom.uuid, status: 'CLR', phase_number: 8 } }
    let(:claim_seventeen) { { id: SecureRandom.uuid, status: 'CLD', phase_number: 8 } }
    let(:claim_eightteen) { { id: SecureRandom.uuid, status: 'error' } }
    let(:claim_nineteen) { { id: SecureRandom.uuid, status: 'errored' } }

    let(:claims) do
      [claim_one, claim_two, claim_three, claim_four, claim_five, claim_six, claim_seven, claim_eight,
       claim_nine, claim_ten, claim_eleven, claim_twelve, claim_thirteen, claim_fourteen, claim_fifthteen,
       claim_sixteen, claim_seventeen, claim_eightteen, claim_nineteen]
    end
    let(:mapper) { ClaimsApi::BGSClaimStatusMapper.new }

    context 'maps keys to values' do
      it 'maps to value' do
        claims.each do |claim|
          claim[:status] = mapper.name(claim)
        end

        expect(claim_one[:status]).to eq('PENDING')
        expect(claim_three[:status]).to eq('PENDING')
        expect(claim_two[:status]).to eq('CANCELED')
        expect(claim_four[:status]).to eq('INITIAL_REVIEW')
        expect(claim_five[:status]).to eq('COMPLETE')
        expect(claim_six[:status]).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
        expect(claim_seven[:status]).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
        expect(claim_eight[:status]).to eq('COMPLETE')
        expect(claim_nine[:status]).to eq('CLAIM_RECEIVED')
        expect(claim_ten[:status]).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
        expect(claim_eleven[:status]).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
        expect(claim_twelve[:status]).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
        expect(claim_thirteen[:status]).to eq('EVIDENCE_GATHERING_REVIEW_DECISION')
        expect(claim_fourteen[:status]).to eq('PREPARATION_FOR_NOTIFICATION')
        expect(claim_fifthteen[:status]).to eq('PREPARATION_FOR_NOTIFICATION')
        expect(claim_sixteen[:status]).to eq('COMPLETE')
        expect(claim_seventeen[:status]).to eq('COMPLETE')
        expect(claim_eightteen[:status]).to eq('ERRORED')
        expect(claim_nineteen[:status]).to eq('ERRORED')
      end
    end
  end
end
