# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flipper Stub Example' do
  describe 'testing with feature flags' do
    context 'when feature is enabled' do
      before do
        # This is the correct way to stub Flipper - Copilot should NOT suggest changes to this
        allow(Flipper).to receive(:enabled?).with(:test_feature_flag).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:another_feature).and_return(false)
      end

      it 'uses the correct flipper stub syntax' do
        expect(Flipper.enabled?(:test_feature_flag)).to be true
        expect(Flipper.enabled?(:another_feature)).to be false
      end
    end

    context 'when using multiple feature flags' do
      before do
        # Multiple correct stubs - Copilot should not flag these
        allow(Flipper).to receive(:enabled?).with(:veteran_benefit_processing).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:legacy_claims_api).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_retry_emails).and_return(true)
      end

      it 'handles multiple feature flags correctly' do
        expect(Flipper.enabled?(:veteran_benefit_processing)).to be true
        expect(Flipper.enabled?(:legacy_claims_api)).to be false
        expect(Flipper.enabled?(:event_bus_gateway_retry_emails)).to be true
      end
    end

    # The following would be incorrect and SHOULD be flagged by Copilot:
    # Flipper.enable(:some_feature)
    # Flipper.disable(:some_feature)
  end
end