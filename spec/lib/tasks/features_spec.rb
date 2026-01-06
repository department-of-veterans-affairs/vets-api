# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'features:setup rake task', type: :task do
  before(:all) do
    load Rails.root.join('lib', 'tasks', 'features.rake')
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['features:setup'] }

  # Store original feature state to restore after tests (eager evaluation so it runs before the `before` block)
  let!(:original_features) { Flipper.features.map { |f| [f.name, f.state] }.to_h }

  before do
    task.reenable
    # Clear any existing features for test isolation
    Flipper.features.each(&:remove)
  end

  after do
    # Clean up any test-created features and restore original state
    Flipper.features.each(&:remove)
    original_features.each do |name, _state|
      Flipper.add(name) unless Flipper.exist?(name)
    end
  end

  describe 'features:setup' do
    it 'preloads the Rails environment' do
      expect(task.prerequisites).to include 'environment'
    end

    context 'when features do not exist' do
      it 'adds features from config/features.yml' do
        expect { task.invoke }.not_to raise_error
        expect(Flipper.features.map(&:name)).to include('this_is_only_a_test')
      end

      it 'logs added features' do
        allow(Rails.logger).to receive(:info).and_call_original
        allow(Rails.logger).to receive(:warn).and_call_original
        task.invoke
        expect(Rails.logger).to have_received(:info).with(/features:setup added \d+ features/)
      end
    end

    context 'when features already exist' do
      before do
        Flipper.add('this_is_only_a_test')
      end

      it 'does not duplicate existing features' do
        task.invoke
        # Should not add duplicates
        expect(Flipper.features.select { |f| f.name == 'this_is_only_a_test' }.count).to eq(1)
      end

      it 'does not modify state of existing features' do
        # Feature exists but is disabled
        expect(Flipper.enabled?('this_is_only_a_test')).to be false

        task.invoke

        # Task should not change existing feature state
        expect(Flipper.enabled?('this_is_only_a_test')).to be false
      end

      it 'logs when no new features are added' do
        # Add all features first
        YAML.safe_load(Rails.root.join('config', 'features.yml').read)['features'].each_key do |feature|
          Flipper.add(feature) unless Flipper.exist?(feature)
        end

        allow(Rails.logger).to receive(:info).and_call_original
        allow(Rails.logger).to receive(:warn).and_call_original

        task.reenable
        task.invoke

        expect(Rails.logger).to have_received(:info).with(/features:setup - no new features to add/)
      end
    end

    context 'in test environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
      end

      it 'enables new features by default' do
        task.invoke
        expect(Flipper.enabled?('this_is_only_a_test')).to be true
      end
    end

    context 'in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      context 'when feature has enable_in_development set' do
        let(:feature_name) { 'accredited_representative_portal_frontend' }

        it 'enables new features with enable_in_development: true' do
          task.invoke
          expect(Flipper.enabled?(feature_name)).to be true
        end
      end

      context 'when feature does not have enable_in_development set' do
        let(:feature_name) { 'this_is_only_a_test' }

        it 'does not enable features without enable_in_development' do
          task.invoke
          expect(Flipper.enabled?(feature_name)).to be false
        end
      end
    end

    context 'when features exist in database but not in config' do
      before do
        Flipper.add('orphaned_feature_not_in_config')
      end

      it 'removes orphaned features from the database' do
        expect(Flipper.exist?('orphaned_feature_not_in_config')).to be true

        allow(Rails.logger).to receive(:info).and_call_original
        task.invoke

        expect(Flipper.exist?('orphaned_feature_not_in_config')).to be false
      end

      it 'logs removed features' do
        allow(Rails.logger).to receive(:info).and_call_original
        task.invoke
        expect(Rails.logger).to have_received(:info).with(/features:setup removed \d+ orphaned features.*orphaned_feature_not_in_config/)
      end
    end

    describe 'idempotency' do
      it 'is safe to run multiple times' do
        expect { task.invoke }.not_to raise_error
        task.reenable
        expect { task.invoke }.not_to raise_error
        task.reenable
        expect { task.invoke }.not_to raise_error
      end

      it 'does not modify existing feature states on subsequent runs' do
        # First run creates the feature
        task.invoke

        # Manually change the feature state
        Flipper.enable('this_is_only_a_test')
        expect(Flipper.enabled?('this_is_only_a_test')).to be true

        # Second run should not modify existing feature
        task.reenable
        task.invoke

        # Feature should still be enabled because task only enables NEW features
        expect(Flipper.enabled?('this_is_only_a_test')).to be true
      end
    end

    describe 'error handling' do
      it 'raises and logs error when config file is invalid' do
        allow(Rails.root).to receive(:join).with('config', 'features.yml').and_return(
          double(read: 'invalid: yaml: content: [')
        )
        allow(Rails.logger).to receive(:error)

        expect { task.invoke }.to raise_error(Psych::SyntaxError)
        expect(Rails.logger).to have_received(:error).with(/Error processing Flipper features/)
      end
    end
  end
end
