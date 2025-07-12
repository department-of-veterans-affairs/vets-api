# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FlipperUtils do
  describe '.safe_enabled?' do
    let(:feature_name) { :some_feature }

    context 'when Flipper is defined and initialized' do
      before do
        stub_const('Flipper', double('Flipper'))

        allow(Flipper).to receive(:respond_to?).with(:enabled).and_return(true)
        allow(Flipper).to receive(:enabled?).with(feature_name).and_return(true)
      end

      it 'returns true if the feature is enabled' do
        expect(described_class.safe_enabled?(feature_name)).to be(true)
      end

      it 'returns false if the feature is disabled' do
        allow(Flipper).to receive(:enabled?).with(feature_name).and_return(false)
        expect(described_class.safe_enabled?(feature_name)).to be(false)
      end
    end

    context 'when Flipper is not enabled' do
      before do
        stub_const('Flipper', double('Flipper'))

        allow(Flipper).to receive(:respond_to?).with(:enabled).and_return(false)
      end

      it 'returns false' do
        expect(described_class.safe_enabled?(feature_name)).to be(false)
      end
    end
  end
end
