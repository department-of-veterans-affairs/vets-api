# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtsApi::V0::DigitalDispute do
  # Placeholder for future DMC integration
  describe 'constants' do
    it 'defines STATS_KEY' do
      expect(described_class::STATS_KEY).to eq('api.digital_dispute_submission')
    end
  end
end
