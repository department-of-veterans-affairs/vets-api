# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HlrStatus, type: :concern do
  context 'when verifying model status structures' do
    let(:local_statuses) { subject::STATUSES }

    it 'fails if central mail statuses are not included' do
      additional_statuses = [*subject::IN_PROCESS_STATUSES, *subject::COMPLETE_STATUSES]

      expect(local_statuses).to include(*additional_statuses)
    end

    context 'statuses' do
      it 'includes the V1 expected statuses' do
        statuses = %w[pending submitting submitted processing error uploaded received success expired complete]
        expect(described_class::V1_STATUSES).to match_array(statuses)
      end

      it 'includes the V2 expected statuses' do
        statuses = %w[pending submitting submitted success processing error complete]
        expect(described_class::V2_STATUSES).to match_array(statuses)
      end

      it 'includes the V0 expected statuses' do
        statuses = %w[pending submitting submitted success processing error complete]
        expect(described_class::V0_STATUSES).to match_array(statuses)
      end
    end
  end
end
