# frozen_string_literal: true

require 'rails_helper'
require 'flipper/utilities/bulk_feature_checker'

RSpec.describe Flipper::Utilities::BulkFeatureChecker do
  describe '.enabled_status' do
    subject { Flipper::Utilities::BulkFeatureChecker.enabled_status(features) }

    let(:features) { [] }
    let(:empty_result) do
      {
        enabled: [],
        disabled: []
      }
    end

    context 'when empty array is provided for features' do
      it 'returns an empty result' do
        expect(subject).to match_array(empty_result)
      end
    end

    context 'when nil is provided for features' do
      let(:features) { nil }

      it 'returns an empty result' do
        expect(subject).to match_array(empty_result)
      end
    end

    context 'when all provided features are enabled' do
      let(:features) { %w[enabled_feature1 enabled_feature2] }
      let(:expected_result) do
        {
          enabled: features,
          disabled: []
        }
      end

      before do
        features.each do |feature|
          Flipper.enable(feature) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end
      end

      it 'returns all features in the enabled key' do
        expect(subject).to match_array(expected_result)
      end
    end

    context 'when all provided features are disabled' do
      let(:features) { %w[disabled_feature1 disabled_feature2] }
      let(:expected_result) do
        {
          enabled: [],
          disabled: features
        }
      end

      before do
        features.each do |feature|
          Flipper.disable(feature) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end
      end

      it 'returns all features in the disabled key' do
        expect(subject).to match_array(expected_result)
      end
    end

    context 'when features in various states are provided' do
      let(:enabled_features) { %w[enabled_feature3 enabled_feature4] }
      let(:disabled_features) { %w[disabled_feature3 disabled_feature4] }
      let(:features) { enabled_features + disabled_features }
      let(:expected_result) do
        {
          enabled: enabled_features,
          disabled: disabled_features
        }
      end

      before do
        enabled_features.each do |feature|
          Flipper.enable(feature) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end

        disabled_features.each do |feature|
          Flipper.disable(feature) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end
      end

      it 'returns all features associated with the correct keys' do
        expect(subject).to match_array(expected_result)
      end
    end

    context 'when provided feature keys are symbols' do
      let(:enabled_features) { %i[enabled_feature5 enabled_feature6] }
      let(:disabled_features) { %i[disabled_feature5 disabled_feature6] }
      let(:features) { enabled_features + disabled_features }
      let(:expected_result) do
        {
          enabled: enabled_features.map(&:to_s),
          disabled: disabled_features.map(&:to_s)
        }
      end

      before do
        enabled_features.each do |feature|
          Flipper.enable(feature.to_s) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end

        disabled_features.each do |feature|
          Flipper.disable(feature.to_s) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end
      end

      it 'returns all features associated with the correct keys' do
        expect(subject).to match_array(expected_result)
      end
    end
  end
end
