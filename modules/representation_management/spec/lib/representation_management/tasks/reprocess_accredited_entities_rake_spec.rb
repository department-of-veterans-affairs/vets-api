# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'representation_management:accreditation:reprocess rake task', type: :task do
  before do
    # Provide both task name and directory to search
    rake_file_path = Rails.root.join('modules', 'representation_management', 'lib', 'tasks')
    Rake.application.rake_require('reprocess_accredited_entities', [rake_file_path])
    Rake::Task.define_task(:environment)
    task.reenable # Reset the task for each test
  end

  let(:task_path) { 'representation_management:accreditation:reprocess' }
  let(:task) { Rake::Task[task_path] }

  describe 'task arguments validation' do
    it 'exits with error when no rep_types are provided' do
      expect do
        expect do
          task.invoke
        end.to output(/Error: Please specify representative types to reprocess/).to_stdout
      end.to raise_error(SystemExit)
    end

    it 'exits with error when invalid representative types are provided' do
      expect do
        expect do
          task.invoke('invalid_type')
        end.to output(/Error: Invalid representative types: invalid_type/).to_stdout
      end.to raise_error(SystemExit)
    end

    it 'validates multiple representative types' do
      expect do
        expect do
          task.invoke('agents,invalid_type')
        end.to output(/Error: Invalid representative types: invalid_type/).to_stdout
      end.to raise_error(SystemExit)
    end

    it 'accepts valid representative types' do
      valid_types = ['agents']

      allow(RepresentationManagement::AccreditedEntitiesQueueUpdates).to receive(:perform_async).with(valid_types)

      expect do
        task.invoke('agents')
      end.to output(/Starting manual reprocessing for: agents/).to_stdout
    end

    it 'accepts multiple valid representative types' do
      valid_types = %w[agents attorneys]

      allow(RepresentationManagement::AccreditedEntitiesQueueUpdates).to receive(:perform_async).with(valid_types)

      expect do
        task.invoke('agents,attorneys')
      end.to output(/Starting manual reprocessing for: agents, attorneys/).to_stdout
    end
  end

  describe 'job processing' do
    it 'enqueues a job with the correct parameters for agents' do
      expect(RepresentationManagement::AccreditedEntitiesQueueUpdates).to receive(:perform_async)
        .with(['agents'])

      expect do
        task.invoke('agents')
      end.to output(/Job enqueued successfully for agents/).to_stdout
    end

    it 'enqueues a job with the correct parameters for attorneys' do
      expect(RepresentationManagement::AccreditedEntitiesQueueUpdates).to receive(:perform_async)
        .with(['attorneys'])

      expect do
        task.invoke('attorneys')
      end.to output(/Job enqueued successfully for attorneys/).to_stdout
    end

    it 'handles job enqueuing errors gracefully' do
      allow(RepresentationManagement::AccreditedEntitiesQueueUpdates).to receive(:perform_async)
        .and_raise(StandardError.new('Test error'))

      expect do
        expect do
          task.invoke('agents')
        end.to output(/Error scheduling reprocessing job: Test error/).to_stdout
      end.to raise_error(SystemExit)
    end

    it 'exits with error when only representatives is specified' do
      expect do
        expect do
          task.invoke('representatives')
        end.to output(/Error: Representatives and VSOs must be processed together/).to_stdout
      end.to raise_error(SystemExit)
    end

    it 'exits with error when only veteran_service_organizations is specified' do
      expect do
        expect do
          task.invoke('veteran_service_organizations')
        end.to output(/Error: Representatives and VSOs must be processed together/).to_stdout
      end.to raise_error(SystemExit)
    end

    # rubocop:disable Layout/LineLength
    it 'processes both reps and VSOs when both are explicitly specified' do
      expect(RepresentationManagement::AccreditedEntitiesQueueUpdates).to receive(:perform_async)
        .with(%w[representatives veteran_service_organizations])

      expect do
        task.invoke('representatives,veteran_service_organizations')
      end.to output(
        /Starting manual reprocessing for: representatives, veteran_service_organizations.*Job enqueued successfully for representatives, veteran_service_organizations/m
      ).to_stdout
    end
    # rubocop:enable Layout/LineLength

    it 'handles all four entity types' do
      expect(RepresentationManagement::AccreditedEntitiesQueueUpdates).to receive(:perform_async)
        .with(%w[agents attorneys representatives veteran_service_organizations])

      expect do
        task.invoke('agents,attorneys,representatives,veteran_service_organizations')
      end.to output(
        /Job enqueued successfully for agents, attorneys, representatives, veteran_service_organizations/
      ).to_stdout
    end

    it 'exits with error when mixing other types with only one VSO type' do
      expect do
        expect do
          task.invoke('attorneys,representatives')
        end.to output(/Error: Representatives and VSOs must be processed together/).to_stdout
      end.to raise_error(SystemExit)
    end

    it 'processes correctly when mixing other types with both VSO types' do
      expect(RepresentationManagement::AccreditedEntitiesQueueUpdates).to receive(:perform_async)
        .with(%w[attorneys representatives veteran_service_organizations])

      expect do
        task.invoke('attorneys,representatives,veteran_service_organizations')
      end.to output(/Job enqueued successfully for attorneys, representatives, veteran_service_organizations/).to_stdout
    end
  end

  describe 'output messages' do
    before do
      allow(RepresentationManagement::AccreditedEntitiesQueueUpdates).to receive(:perform_async)
        .with(['agents'])
    end

    it 'outputs confirmation that the job will bypass count validation' do
      expect do
        task.invoke('agents')
      end.to output(/Processing agents will bypass count validation/).to_stdout
    end
  end
end
