# frozen_string_literal: true

require 'set'
require 'singleton'

module FeatureToggleCoverage
  class Tracker
    include Singleton

    attr_reader :tested_toggles

    def initialize
      @tested_toggles = Hash.new { |h, k| h[k] = Set.new }
    end

    def record_toggle_test(feature_name, state)
      @tested_toggles[feature_name.to_s].add(state)
    end

    def fully_tested?(feature_name)
      states = @tested_toggles[feature_name.to_s]
      states.include?(:enabled) && states.include?(:disabled)
    end

    def reset!
      @tested_toggles.clear
    end

    def coverage_report
      report = {}
      @tested_toggles.each do |feature, states|
        report[feature] = {
          enabled: states.include?(:enabled),
          disabled: states.include?(:disabled),
          fully_tested: fully_tested?(feature)
        }
      end
      report
    end
  end
end

# Custom RSpec matcher for tracking feature toggle testing
RSpec::Matchers.define :test_feature_toggle do |feature_name|
  match do |actual|
    # Track that this toggle was tested
    state = @state || :enabled
    FeatureToggleCoverage::Tracker.instance.record_toggle_test(feature_name, state)
    
    # Perform the actual assertion based on state
    if state == :enabled
      expect(Flipper).to receive(:enabled?).with(feature_name).and_return(true)
    else
      expect(Flipper).to receive(:enabled?).with(feature_name).and_return(false)
    end
    
    true
  end

  chain :when_enabled do
    @state = :enabled
  end

  chain :when_disabled do
    @state = :disabled
  end

  description do
    state_desc = @state ? "when #{@state}" : "when enabled"
    "test feature toggle #{feature_name} #{state_desc}"
  end

  failure_message do |actual|
    "expected to test feature toggle #{feature_name} when #{@state || 'enabled'}"
  end
end

# Shared examples for common feature toggle testing patterns
RSpec.shared_examples 'feature toggle behavior' do |feature_name, options = {}|
  enabled_behavior = options[:enabled_behavior] || 'behaves correctly when enabled'
  disabled_behavior = options[:disabled_behavior] || 'behaves correctly when disabled'

  context "with #{feature_name} feature toggle" do
    context 'when enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(feature_name).and_return(true)
        FeatureToggleCoverage::Tracker.instance.record_toggle_test(feature_name, :enabled)
      end

      it enabled_behavior do
        # The including spec should define expected behavior
        expect { subject }.not_to raise_error
      end
    end

    context 'when disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(feature_name).and_return(false)
        FeatureToggleCoverage::Tracker.instance.record_toggle_test(feature_name, :disabled)
      end

      it disabled_behavior do
        # The including spec should define expected behavior
        expect { subject }.not_to raise_error
      end
    end
  end
end

# Helper method to automatically track Flipper stubs
module FlipperStubTracker
  def allow_flipper_enabled(feature_name, enabled: true)
    state = enabled ? :enabled : :disabled
    FeatureToggleCoverage::Tracker.instance.record_toggle_test(feature_name, state)
    allow(Flipper).to receive(:enabled?).with(feature_name).and_return(enabled)
  end
end

RSpec.configure do |config|
  config.include FlipperStubTracker
  
  # Reset coverage tracker before each test suite
  config.before(:suite) do
    FeatureToggleCoverage::Tracker.instance.reset!
  end
end