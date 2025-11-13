# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditationDataIngestionLog, type: :model do
  describe 'enums' do
    it { is_expected.to define_enum_for(:dataset).with_values(accreditation_api: 0, trexler_file: 1) }
    it { is_expected.to define_enum_for(:status).with_values(running: 0, success: 1, failed: 2) }

    it 'defines agents_status enum with prefix' do
      expect(described_class.agents_statuses).to eq(
        'not_started' => 0,
        'running' => 1,
        'success' => 2,
        'failed' => 3
      )
    end

    it 'defines attorneys_status enum with prefix' do
      expect(described_class.attorneys_statuses).to eq(
        'not_started' => 0,
        'running' => 1,
        'success' => 2,
        'failed' => 3
      )
    end

    it 'defines representatives_status enum with prefix' do
      expect(described_class.representatives_statuses).to eq(
        'not_started' => 0,
        'running' => 1,
        'success' => 2,
        'failed' => 3
      )
    end

    it 'defines veteran_service_organizations_status enum with prefix' do
      expect(described_class.veteran_service_organizations_statuses).to eq(
        'not_started' => 0,
        'running' => 1,
        'success' => 2,
        'failed' => 3
      )
    end
  end

  describe '.start_ingestion!' do
    it 'creates a new log with running status' do
      log = described_class.start_ingestion!(dataset: :accreditation_api)

      expect(log).to be_persisted
      expect(log.dataset).to eq('accreditation_api')
      expect(log.status).to eq('running')
      expect(log.started_at).to be_within(1.second).of(Time.current)
    end

    it 'creates a log for trexler_file dataset' do
      log = described_class.start_ingestion!(dataset: :trexler_file)

      expect(log.dataset).to eq('trexler_file')
      expect(log.running?).to be true
    end

    it 'initializes all entity statuses to not_started' do
      log = described_class.start_ingestion!(dataset: :accreditation_api)

      expect(log.agents_not_started?).to be true
      expect(log.attorneys_not_started?).to be true
      expect(log.representatives_not_started?).to be true
      expect(log.veteran_service_organizations_not_started?).to be true
    end
  end

  describe '.most_recent_successful' do
    let!(:old_log) { create(:accreditation_data_ingestion_log, :completed, finished_at: 2.days.ago) }
    let!(:recent_log) { create(:accreditation_data_ingestion_log, :completed, finished_at: 1.day.ago) }
    let!(:running_log) { create(:accreditation_data_ingestion_log, finished_at: nil) }

    it 'returns the most recent successfully completed log' do
      expect(described_class.most_recent_successful).to eq(recent_log)
    end

    it 'does not return running logs' do
      expect(described_class.most_recent_successful).not_to eq(running_log)
    end
  end

  describe '.most_recent_successful_for_dataset' do
    let!(:api_log) do
      create(:accreditation_data_ingestion_log, :completed, dataset: :accreditation_api, finished_at: 1.day.ago)
    end
    let!(:trexler_log) do
      create(:accreditation_data_ingestion_log, :trexler_file, :completed, finished_at: 2.days.ago)
    end

    it 'returns the most recent successful log for accreditation_api' do
      expect(described_class.most_recent_successful_for_dataset(:accreditation_api)).to eq(api_log)
    end

    it 'returns the most recent successful log for trexler_file' do
      expect(described_class.most_recent_successful_for_dataset(:trexler_file)).to eq(trexler_log)
    end
  end

  describe '.current_running_for_dataset' do
    let!(:api_log) { create(:accreditation_data_ingestion_log, dataset: :accreditation_api, status: :running) }
    let!(:trexler_log) do
      create(:accreditation_data_ingestion_log, dataset: :trexler_file, status: :running)
    end

    it 'returns the running log for accreditation_api' do
      expect(described_class.current_running_for_dataset(:accreditation_api)).to eq(api_log)
    end

    it 'returns the running log for trexler_file' do
      expect(described_class.current_running_for_dataset(:trexler_file)).to eq(trexler_log)
    end

    it 'returns nil when no running log exists' do
      api_log.update(status: :success, finished_at: Time.current)
      expect(described_class.current_running_for_dataset(:accreditation_api)).to be_nil
    end
  end

  describe '#mark_entity_running!' do
    let(:log) { create(:accreditation_data_ingestion_log) }

    it 'marks agents as running' do
      log.mark_entity_running!(:agents)
      expect(log.agents_running?).to be true
    end

    it 'marks attorneys as running' do
      log.mark_entity_running!(:attorneys)
      expect(log.attorneys_running?).to be true
    end

    it 'marks representatives as running' do
      log.mark_entity_running!(:representatives)
      expect(log.representatives_running?).to be true
    end

    it 'marks veteran_service_organizations as running' do
      log.mark_entity_running!(:veteran_service_organizations)
      expect(log.veteran_service_organizations_running?).to be true
    end

    it 'persists the change' do
      log.mark_entity_running!(:agents)
      log.reload
      expect(log.agents_running?).to be true
    end

    it 'raises error for invalid entity type' do
      expect { log.mark_entity_running!(:invalid_type) }.to raise_error(ArgumentError)
    end
  end

  describe '#mark_entity_success!' do
    let(:log) { create(:accreditation_data_ingestion_log) }

    it 'marks agents as success' do
      log.mark_entity_success!(:agents)
      expect(log.agents_success?).to be true
    end

    it 'stores metrics' do
      log.mark_entity_success!(:agents, count: 100, duration: 45.2)
      expect(log.metrics['agents']['count']).to eq(100)
      expect(log.metrics['agents']['duration']).to eq(45.2)
    end

    it 'persists the change and metrics' do
      log.mark_entity_success!(:attorneys, count: 200)
      log.reload
      expect(log.attorneys_success?).to be true
      expect(log.metrics['attorneys']['count']).to eq(200)
    end

    it 'merges metrics for the same entity' do
      log.mark_entity_success!(:agents, count: 100)
      log.mark_entity_success!(:agents, duration: 30)
      expect(log.metrics['agents']['count']).to eq(100)
      expect(log.metrics['agents']['duration']).to eq(30)
    end
  end

  describe '#mark_entity_failed!' do
    let(:log) { create(:accreditation_data_ingestion_log) }

    it 'marks agents as failed' do
      log.mark_entity_failed!(:agents)
      expect(log.agents_failed?).to be true
    end

    it 'stores error information' do
      log.mark_entity_failed!(:agents, error: 'Connection timeout', count: 50)
      expect(log.metrics['agents']['error']).to eq('Connection timeout')
      expect(log.metrics['agents']['count']).to eq(50)
    end

    it 'persists the change and error info' do
      log.mark_entity_failed!(:attorneys, error: 'API error')
      log.reload
      expect(log.attorneys_failed?).to be true
      expect(log.metrics['attorneys']['error']).to eq('API error')
    end
  end

  describe '#complete_ingestion!' do
    let(:log) { create(:accreditation_data_ingestion_log) }

    it 'marks the log as success' do
      log.complete_ingestion!
      expect(log.success?).to be true
    end

    it 'sets finished_at timestamp' do
      log.complete_ingestion!
      expect(log.finished_at).to be_within(1.second).of(Time.current)
    end

    it 'stores overall metrics' do
      log.complete_ingestion!(total_duration: 120.5, total_records: 5000)
      expect(log.metrics['total_duration']).to eq(120.5)
      expect(log.metrics['total_records']).to eq(5000)
    end

    it 'persists all changes' do
      log.complete_ingestion!(total_duration: 60)
      log.reload
      expect(log.success?).to be true
      expect(log.finished_at).not_to be_nil
      expect(log.metrics['total_duration']).to eq(60)
    end
  end

  describe '#fail_ingestion!' do
    let(:log) { create(:accreditation_data_ingestion_log) }

    it 'marks the log as failed' do
      log.fail_ingestion!
      expect(log.failed?).to be true
    end

    it 'sets finished_at timestamp' do
      log.fail_ingestion!
      expect(log.finished_at).to be_within(1.second).of(Time.current)
    end

    it 'stores error information' do
      log.fail_ingestion!(error: 'API connection failed', partial_results: true)
      expect(log.metrics['error']).to eq('API connection failed')
      expect(log.metrics['partial_results']).to be true
    end
  end

  describe '#duration' do
    it 'returns nil when not finished' do
      log = create(:accreditation_data_ingestion_log, finished_at: nil)
      expect(log.duration).to be_nil
    end

    it 'calculates duration when finished' do
      started = 1.hour.ago
      finished = Time.current
      log = create(:accreditation_data_ingestion_log, started_at: started, finished_at: finished)

      expect(log.duration).to be_within(1).of(3600)
    end
  end

  describe '#all_entities_completed?' do
    let(:log) { create(:accreditation_data_ingestion_log) }

    it 'returns false when entities are not_started' do
      expect(log.all_entities_completed?).to be false
    end

    it 'returns false when some entities are running' do
      log.update(agents_status: :success, attorneys_status: :running)
      expect(log.all_entities_completed?).to be false
    end

    it 'returns true when all entities are success' do
      log.update(
        agents_status: :success,
        attorneys_status: :success,
        representatives_status: :success,
        veteran_service_organizations_status: :success
      )
      expect(log.all_entities_completed?).to be true
    end

    it 'returns true when all entities are either success or failed' do
      log.update(
        agents_status: :success,
        attorneys_status: :failed,
        representatives_status: :success,
        veteran_service_organizations_status: :failed
      )
      expect(log.all_entities_completed?).to be true
    end
  end

  describe '#any_entity_failed?' do
    let(:log) { create(:accreditation_data_ingestion_log) }

    it 'returns false when no entities have failed' do
      log.update(
        agents_status: :success,
        attorneys_status: :success,
        representatives_status: :not_started,
        veteran_service_organizations_status: :running
      )
      expect(log.any_entity_failed?).to be false
    end

    it 'returns true when any entity has failed' do
      log.update(agents_status: :failed)
      expect(log.any_entity_failed?).to be true
    end
  end

  describe '#entity_statuses' do
    let(:log) { create(:accreditation_data_ingestion_log, :completed) }

    it 'returns a hash of all entity statuses' do
      statuses = log.entity_statuses

      expect(statuses).to be_a(Hash)
      expect(statuses.keys).to contain_exactly('agents', 'attorneys', 'representatives',
                                               'veteran_service_organizations')
      expect(statuses['agents']).to eq('success')
    end
  end

  describe 'ENTITY_TYPES constant' do
    it 'contains all valid entity types' do
      expect(described_class::ENTITY_TYPES).to contain_exactly(
        'agents',
        'attorneys',
        'representatives',
        'veteran_service_organizations'
      )
    end
  end

  describe 'integration test: full ingestion flow' do
    it 'tracks a complete successful ingestion' do
      # Start ingestion
      log = described_class.start_ingestion!(dataset: :accreditation_api)
      expect(log.running?).to be true

      # Process agents
      log.mark_entity_running!(:agents)
      log.mark_entity_success!(:agents, count: 100)

      # Process attorneys
      log.mark_entity_running!(:attorneys)
      log.mark_entity_success!(:attorneys, count: 200)

      # Process representatives
      log.mark_entity_running!(:representatives)
      log.mark_entity_success!(:representatives, count: 300)

      # Process VSOs
      log.mark_entity_running!(:veteran_service_organizations)
      log.mark_entity_success!(:veteran_service_organizations, count: 50)

      # Complete
      log.complete_ingestion!(total_records: 650)

      # Verify final state
      log.reload
      expect(log.success?).to be true
      expect(log.all_entities_completed?).to be true
      expect(log.any_entity_failed?).to be false
      expect(log.metrics['agents']['count']).to eq(100)
      expect(log.metrics['total_records']).to eq(650)
      expect(log.duration).to be_positive
    end

    it 'tracks a partially failed ingestion' do
      log = described_class.start_ingestion!(dataset: :trexler_file)

      # Some succeed
      log.mark_entity_running!(:agents)
      log.mark_entity_success!(:agents, count: 100)

      # Some fail
      log.mark_entity_running!(:attorneys)
      log.mark_entity_failed!(:attorneys, error: 'Connection timeout')

      # Overall failure
      log.fail_ingestion!(error: 'Partial failure', completed_entities: 1)

      log.reload
      expect(log.failed?).to be true
      expect(log.agents_success?).to be true
      expect(log.attorneys_failed?).to be true
      expect(log.any_entity_failed?).to be true
      expect(log.metrics['error']).to eq('Partial failure')
    end
  end
end
