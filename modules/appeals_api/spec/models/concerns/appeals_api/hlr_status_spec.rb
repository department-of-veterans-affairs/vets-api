# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HlrStatus, type: :concern do
  context 'when verifying model status structures' do
    let(:local_statuses) { subject::STATUSES }

    it 'fails if central mail statuses are not included' do
      additional_statuses = [*subject::RECEIVED_OR_PROCESSING, *subject::COMPLETE_STATUSES]

      expect(local_statuses).to include(*additional_statuses)
    end

    it 'includes the expected statuses' do
      statuses = %w[pending submitting submitted processing error uploaded received success expired]
      expect(described_class::STATUSES).to eq(statuses)
    end
  end
end
