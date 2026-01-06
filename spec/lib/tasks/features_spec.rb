# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'features:setup rake task', type: :task do
  before(:all) do
    load Rails.root.join('lib', 'tasks', 'features.rake')
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['features:setup'] }

  before do
    task.reenable
    # Clear any existing features
    Flipper.features.each(&:remove)
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

        it 'enables features with enable_in_development: true' do
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

      it 'warns about orphaned features' do
        allow(Rails.logger).to receive(:info).and_call_original
        allow(Rails.logger).to receive(:warn).and_call_original
        task.invoke
        expect(Rails.logger).to have_received(:warn).with(/consider removing features.*orphaned_feature_not_in_config/i)
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

      it 'maintains feature state when run multiple times' do
        task.invoke
        Flipper.enable('this_is_only_a_test')
        expect(Flipper.enabled?('this_is_only_a_test')).to be true

        task.reenable
        task.invoke

        # Feature should still be enabled (task doesn't modify existing features)
        expect(Flipper.enabled?('this_is_only_a_test')).to be true
      end
    end
  end
end
