# frozen_string_literal: true

require 'rails_helper'
require 'flipper/utilities/bulk_feature_manager'

module Flipper
  module Utilities
    RSpec.describe BulkFeatureManager do
      subject(:manager) { described_class.new(memory) }

      # Use an in-memory Flipper instance passed into the manager for isolation
      let(:memory) { Flipper.new(Flipper::Adapters::Memory.new) }

      describe 'static helpers' do
        describe '.setup_features' do
          it 'creates a BulkFeatureManager and calls setup' do
            manager_instance = instance_double(described_class)
            allow(described_class).to receive(:new).with(Flipper).and_return(manager_instance)
            allow(manager_instance).to receive_messages(
              setup: nil,
              added_features: [],
              enabled_features: [],
              removed_features: []
            )

            Flipper::Utilities.setup_features
            expect(described_class).to have_received(:new).with(Flipper)
            expect(manager_instance).to have_received(:setup)
          end
        end
      end

      describe '#setup' do
        it 'adds features from the config and enables them in test env' do
          allow_any_instance_of(described_class).to receive(:features_config).and_return(
            'features' => {
              'f_one' => {},
              'f_two' => { 'enable_in_development' => true }
            }
          )

          expect { manager.setup }.not_to raise_error

          expect(memory.exist?('f_one')).to be true
          expect(memory.exist?('f_two')).to be true

          # In test environment the manager enables new features by default
          expect(memory.enabled?('f_one')).to be true
          expect(memory.enabled?('f_two')).to be true

          expect(manager.added_features).to include('f_one', 'f_two')
          expect(manager.enabled_features).to include('f_one', 'f_two')
        end

        it 'removes orphaned features present in Flipper but absent from config' do
          memory.add('orphan_x')

          allow_any_instance_of(described_class).to receive(:features_config).and_return('features' => {})

          manager.setup

          expect(memory.exist?('orphan_x')).to be false
          expect(manager.removed_features).to include('orphan_x')
        end

        it 'logs and re-raises a Psych::SyntaxError when config parsing fails' do
          manager = described_class.new(memory)
          # Psych::SyntaxError expects constructor args; raise a properly constructed instance
          syntax_error = Psych::SyntaxError.new('config/features.yml', 1, 1, 0, 'invalid yaml', 'while parsing')
          allow_any_instance_of(described_class).to receive(:features_config).and_raise(syntax_error)

          allow(Rails.logger).to receive(:error)

          expect { manager.setup }.to raise_error(Psych::SyntaxError)
          expect(Rails.logger).to have_received(:error).with(%r{Error parsing config/features.yml})
        end
      end
    end
  end
end
