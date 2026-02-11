# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeatureFlagHelper do
  # Dummy class so we can test the concern method
  let(:dummy_class) do
    Class.new do
      include FeatureFlagHelper
      attr_accessor :current_user
    end
  end

  let(:instance) { dummy_class.new }
  let(:user) { build(:user) }
  let(:feature_flag) { :travel_pay_enable_complex_claims }

  before do
    instance.current_user = user
  end

  describe '#verify_feature_flag!' do
    context 'when the feature flag is enabled' do
      it 'does not raise an error' do
        allow(Flipper).to receive(:enabled?).with(feature_flag, instance_of(User)).and_return(true)

        expect { instance.verify_feature_flag!(feature_flag) }.not_to raise_error
      end
    end

    context 'when the feature flag is disabled' do
      it 'raises ServiceUnavailable with default message' do
        allow(Flipper).to receive(:enabled?).with(feature_flag, instance_of(User)).and_return(false)

        expect { instance.verify_feature_flag!(feature_flag) }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::ServiceUnavailable)
          expect(error.errors.first[:detail]).to eq("Travel Pay #{feature_flag} is disabled for user")
        end
      end

      it 'raises ServiceUnavailable with custom message if provided' do
        allow(Flipper).to receive(:enabled?).with(feature_flag, instance_of(User)).and_return(false)
        custom_message = 'Custom feature flag error message'

        expect { instance.verify_feature_flag!(feature_flag, user, error_message: custom_message) }
          .to raise_error do |error|
            expect(error).to be_a(Common::Exceptions::ServiceUnavailable)
            expect(error.errors.first[:detail]).to eq(custom_message)
        end
      end
    end
  end
end
