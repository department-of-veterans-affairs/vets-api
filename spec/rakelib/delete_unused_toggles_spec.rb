# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'flipper rake tasks', type: :task do
  before do
    Rake.application.rake_require '../rakelib/delete_unused_toggles'
    Rake::Task.define_task(:environment)
    allow(YAML).to receive(:load_file).with(features_file_path).and_return(features_config)
  end

  let(:features_config) do
    {
      'features' => {
        'feature_one' => {
          'actor_type' => 'user',
          'description' => 'Test feature one'
        },
        'feature_two' => {
          'actor_type' => 'cookie_id',
          'description' => 'Test feature two'
        }
      }
    }
  end

  let(:features_file_path) { Rails.root.join('config', 'features.yml') }

  describe 'flipper:delete_unused_toggles' do
    let(:task) { Rake::Task['flipper:delete_unused_toggles'] }
    let(:db_features) { %w[feature_one feature_two unused_feature_one unused_feature_two] }
    let(:unused_features) { %w[unused_feature_one unused_feature_two] }

    before do
      task.reenable
      allow(Flipper).to receive(:features).and_return(db_features.map { |name| double(name:) })
    end

    context 'when there are no unused features' do
      let(:db_features) { %w[feature_one feature_two] }

      it 'reports no unused toggles found' do
        expect { task.invoke }.to output(/No unused Flipper toggles found\./).to_stdout
      end
    end

    context 'when there are unused features' do
      context 'with FORCE=true' do
        before do
          ENV['FORCE'] = 'true'
          allow(Flipper).to receive(:remove)
        end

        after do
          ENV.delete('FORCE')
        end

        it 'deletes all unused toggles without confirmation' do
          expect(Flipper).to receive(:remove).with('unused_feature_one')
          expect(Flipper).to receive(:remove).with('unused_feature_two')

          expect { task.invoke }.to output(
            /Found 2 unused Flipper toggles:.*FORCE=true detected.*Successfully deleted: 2/m
          ).to_stdout
        end

        it 'handles deletion errors gracefully' do
          allow(Flipper).to receive(:remove).with('unused_feature_one').and_raise('Deletion failed')
          allow(Flipper).to receive(:remove).with('unused_feature_two')

          expect { task.invoke }.to output(
            /Failed to delete unused_feature_one: Deletion failed.*Successfully deleted: 1.*Failed to delete: 1/m
          ).to_stdout
        end
      end

      context 'without FORCE flag' do
        before do
          allow(Flipper).to receive(:remove)
        end

        context 'when user confirms deletion' do
          before do
            allow($stdin).to receive(:gets).and_return("y\n")
          end

          it 'prompts for confirmation and deletes toggles' do
            expect(Flipper).to receive(:remove).with('unused_feature_one')
            expect(Flipper).to receive(:remove).with('unused_feature_two')

            expect { task.invoke }.to output(
              %r{Do you want to delete these toggles\? \(y/N\):.*Successfully deleted: 2}m
            ).to_stdout
          end
        end

        context 'when user declines deletion' do
          before do
            allow($stdin).to receive(:gets).and_return("n\n")
          end

          it 'cancels operation without deleting' do
            expect(Flipper).not_to receive(:remove)

            expect { task.invoke }.to output(
              %r{Do you want to delete these toggles\? \(y/N\):.*Operation cancelled}m
            ).to_stdout
          end
        end

        context 'when user provides no input (default to no)' do
          before do
            allow($stdin).to receive(:gets).and_return("\n")
          end

          it 'defaults to canceling operation' do
            expect(Flipper).not_to receive(:remove)

            expect { task.invoke }.to output(/Operation cancelled/).to_stdout
          end
        end
      end
    end

    context 'when features.yml file is missing' do
      before do
        allow(YAML).to receive(:load_file).and_raise(Errno::ENOENT)
      end

      it 'handles file not found error' do
        expect { task.invoke }.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe 'flipper:list_unused_toggles' do
    let(:task) { Rake::Task['flipper:list_unused_toggles'] }
    let(:db_features) { %w[feature_one feature_two unused_feature_one unused_feature_two] }

    before do
      task.reenable
      allow(Flipper).to receive(:features).and_return(db_features.map { |name| double(name:) })
    end

    context 'when there are unused features' do
      it 'lists all unused toggles without deleting them' do
        expect(Flipper).not_to receive(:remove)

        expect { task.invoke }.to output(
          /Unused Flipper toggles \(2\):.*unused_feature_one.*unused_feature_two/m
        ).to_stdout
      end
    end

    context 'when there are no unused features' do
      let(:db_features) { %w[feature_one feature_two] }

      it 'reports none found' do
        expect { task.invoke }.to output(
          /Unused Flipper toggles \(0\):.*None found\./m
        ).to_stdout
      end
    end
  end

  describe 'integration scenarios' do
    let(:delete_task) { Rake::Task['flipper:delete_unused_toggles'] }
    let(:list_task) { Rake::Task['flipper:list_unused_toggles'] }

    before do
      delete_task.reenable
      list_task.reenable
    end

    context 'when features exist in both database and config' do
      let(:db_features) { %w[feature_one feature_two shared_feature] }

      before do
        features_config['features']['shared_feature'] = { 'actor_type' => 'user', 'description' => 'Shared' }
        allow(Flipper).to receive(:features).and_return(db_features.map { |name| double(name:) })
      end

      it 'correctly identifies only truly unused features' do
        expect { list_task.invoke }.to output(/Unused Flipper toggles \(0\):.*None found\./m).to_stdout
      end
    end

    context 'with mixed case feature names' do
      let(:db_features) { %w[Feature_One FEATURE_TWO unused_feature] }
      let(:features_config) do
        {
          'features' => {
            'Feature_One' => { 'actor_type' => 'user', 'description' => 'Mixed case feature' },
            'FEATURE_TWO' => { 'actor_type' => 'user', 'description' => 'Upper case feature' }
          }
        }
      end

      before do
        allow(Flipper).to receive(:features).and_return(db_features.map { |name| double(name:) })
      end

      it 'handles case-sensitive feature name matching' do
        expect { list_task.invoke }.to output(
          /Unused Flipper toggles \(1\):.*unused_feature/m
        ).to_stdout
      end
    end
  end
end
