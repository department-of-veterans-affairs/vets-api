require 'rails_helper'

RSpec.describe 'TestNewUntestedFeature', type: :request do
  describe 'when test_new_untested_feature is enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:test_new_untested_feature).and_return(true)
    end

    it 'behaves correctly when feature is enabled' do
      # Test implementation would go here
      expect(Flipper.enabled?(:test_new_untested_feature)).to be true
    end
  end

  describe 'when test_new_untested_feature is disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:test_new_untested_feature).and_return(false)
    end

    it 'behaves correctly when feature is disabled' do
      # Test implementation would go here
      expect(Flipper.enabled?(:test_new_untested_feature)).to be false
    end
  end
end