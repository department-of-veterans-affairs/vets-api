# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::NodStatus, type: :concern do
  context 'when verifying model status structures' do
    let(:local_statuses) { subject::STATUSES }

    it 'fails if central mail statuses are not included' do
      additional_statuses = [*subject::IN_PROCESS_STATUSES, *subject::COMPLETE_STATUSES].uniq

      expect(local_statuses).to include(*additional_statuses)
    end

    it 'includes the expected statuses' do
      statuses = %w[pending submitting submitted success processing error caseflow]
      expect(described_class::STATUSES).to eq(statuses)
    end
  end
end
