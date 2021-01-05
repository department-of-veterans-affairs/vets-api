# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HigherLevelReviewCleanUpWeekOldPii, type: :job do
  describe '#perform' do
    it 'calls AppealsApi::RemovePii' do
      service = instance_double(AppealsApi::RemovePii)
      allow(AppealsApi::RemovePii).to receive(:new).and_return(service)
      allow(service).to receive(:run!)

      described_class.new.perform

      expect(service).to have_received(:run!)
    end
  end
end
