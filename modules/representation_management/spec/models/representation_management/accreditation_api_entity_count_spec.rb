# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditationApiEntityCount, type: :model do
  let(:model) { create(:accreditation_api_entity_count) }

  before do
    # Mock log_error method to prevent actual logging during tests
    allow(model).to receive(:log_error)
    # Mock Slack notification
    allow(model).to receive(:log_to_slack_threshold_channel)
  end

  describe '#save_api_counts' do
    before do
      allow(model).to receive(:current_api_counts).and_return({
                                                                agents: 100,
                                                                attorneys: 100,
                                                                representatives: 100,
                                                                veteran_service_organizations: 100
                                                              })
    end

    it 'assigns values from api counts for each type' do
      model.save_api_counts
      model.reload

      expect(model.agents).to eq(100)
      expect(model.attorneys).to eq(100)
      expect(model.representatives).to eq(100)
      expect(model.veteran_service_organizations).to eq(100)
    end

    it 'only assigns values for valid counts' do
      # Mock the data sources that valid_count? uses internally
      allow(model).to receive_messages(
        current_db_counts: {
          agents: 100, # Previous count
          attorneys: 100,
          representatives: 100,
          veteran_service_organizations: 100
        },
        current_api_counts: {
          agents: 70, # 30% decrease - exceeds 20% threshold
          attorneys: 90, # 10% decrease - within 20% threshold
          representatives: 85, # 15% decrease - within 20% threshold
          veteran_service_organizations: 60 # 40% decrease - exceeds 20% threshold
        }
      )

      model.save_api_counts
      model.reload

      # These should NOT be updated (exceeds threshold)
      expect(model.agents).not_to eq(70)
      expect(model.veteran_service_organizations).not_to eq(60)

      # These SHOULD be updated (within threshold)
      expect(model.attorneys).to eq(90)
      expect(model.representatives).to eq(85)
    end

    it 'calls notify_threshold_exceeded when valid_count? is false' do
      # Setup test data
      allow(model).to receive_messages(current_db_counts: { agents: 100 }, current_api_counts: { agents: 70 })

      # Mock valid_count? to return false for agents
      allow(model).to receive(:valid_count?).with(:agents).and_return(false)
      allow(model).to receive(:valid_count?).with(:attorneys).and_return(true)
      allow(model).to receive(:valid_count?).with(:representatives).and_return(true)
      allow(model).to receive(:valid_count?).with(:veteran_service_organizations).and_return(true)

      # Mock notify_threshold_exceeded
      allow(model).to receive(:notify_threshold_exceeded)

      model.save_api_counts

      # Verify notify_threshold_exceeded was called with correct parameters
      expect(model).to have_received(:notify_threshold_exceeded)
        .with(:agents, 100, 70, -30.0)
    end

    it 'persists the record' do
      model.save_api_counts
      expect(model).to be_persisted
    end

    it 'handles exceptions and logs errors' do
      allow(model).to receive(:save!).and_raise(StandardError.new('Test error'))

      model.save_api_counts

      expect(model).to have_received(:log_error).with('Error saving API counts: Test error')
    end
  end

  describe '#valid_count?' do
    let(:type) { :agents }

    before do
      allow(model).to receive_messages(current_db_counts: { agents: 100 }, current_api_counts: { agents: 110 })
      allow(model).to receive(:notify_threshold_exceeded)
    end

    context 'when no previous count exists' do
      before do
        allow(model).to receive(:current_db_counts).and_return({ agents: nil })
      end

      it 'returns true' do
        expect(model.valid_count?(type)).to be true
      end
    end

    context 'when previous count is zero' do
      before do
        allow(model).to receive(:current_db_counts).and_return({ agents: 0 })
      end

      it 'returns true' do
        expect(model.valid_count?(type)).to be true
      end
    end

    context 'when new count is greater than previous count' do
      before do
        allow(model).to receive_messages(current_db_counts: { agents: 100 }, current_api_counts: { agents: 110 })
      end

      it 'returns true' do
        expect(model.valid_count?(type)).to be true
      end
    end

    context 'when new count is equal to previous count' do
      before do
        allow(model).to receive_messages(current_db_counts: { agents: 100 }, current_api_counts: { agents: 100 })
      end

      it 'returns true' do
        expect(model.valid_count?(type)).to be true
      end
    end

    context 'when new count is less than previous count but within threshold' do
      before do
        # 10% decrease
        allow(model).to receive_messages(current_db_counts: { agents: 100 }, current_api_counts: { agents: 90 })
      end

      it 'returns true' do
        expect(model.valid_count?(type)).to be true
      end
    end

    context 'when new count is less than previous count and exceeds threshold' do
      before do
        # 30% decrease
        allow(model).to receive_messages(current_db_counts: { agents: 100 }, current_api_counts: { agents: 70 })
      end

      it 'returns false' do
        expect(model.valid_count?(type)).to be false
      end
    end
  end

  describe '#notify_threshold_exceeded' do
    it 'logs to Slack with the correct message format' do
      model.send(:notify_threshold_exceeded, :agents, 100, 70, -30.0)

      expected_message = "⚠️ AccreditationApiEntityCount Alert: Agents count decreased beyond threshold!\n" \
                         "Previous: 100\n" \
                         "New: 70\n" \
                         "Decrease: -30.0%\n" \
                         "Threshold: -20.0%\n" \
                         'Action: Update skipped, manual review required'

      expect(model).to have_received(:log_to_slack_threshold_channel).with(expected_message)
    end
  end

  describe '#get_counts_from_api' do
    let(:response_body) { { 'totalRecords' => 100 } }
    let(:response) { instance_double(Faraday::Response, body: response_body) }

    before do
      allow(RepresentationManagement::GCLAWS::Client).to receive(:get_accredited_entities)
        .and_return(response)
    end

    it 'fetches counts for each type from the API' do
      described_class::TYPES.each do |type|
        expect(RepresentationManagement::GCLAWS::Client).to receive(:get_accredited_entities)
          .with(type:, page: 1, page_size: 1)
          .and_return(response)
      end

      result = model.send(:get_counts_from_api)

      described_class::TYPES.each do |type|
        expect(result[type.to_sym]).to eq(100)
      end
    end

    it 'handles API errors for individual types' do
      allow(RepresentationManagement::GCLAWS::Client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::AGENTS, page: 1, page_size: 1)
        .and_raise(StandardError.new('API error'))

      result = model.send(:get_counts_from_api)

      expect(model).to have_received(:log_error).with('Error fetching count for agents: API error')
      expect(result[:agents]).to be_nil
    end
  end

  describe '#get_counts_from_db' do
    let(:unpersisted_model) { RepresentationManagement::AccreditationApiEntityCount.new }
    let(:agents_count) { 15 }
    let(:attorneys_count) { 25 }
    let(:representatives_count) { 35 }

    # Create a factory for the model if it doesn't exist yet
    let!(:previous_count) { create(:accreditation_api_entity_count, created_at: 1.day.ago) }

    context 'with existing count records' do
      it 'returns counts from the latest record' do
        # Create actual database records for individuals
        create_list(:accredited_individual, agents_count, :claims_agent)
        create_list(:accredited_individual, attorneys_count, :attorney)
        create_list(:accredited_individual, representatives_count, :representative)
        create_list(:accredited_organization, 5)

        result = unpersisted_model.send(:get_counts_from_db)

        expect(result[:agents]).to eq(10)
        expect(result[:attorneys]).to eq(10)
        expect(result[:representatives]).to eq(10)
        expect(result[:veteran_service_organizations]).to eq(10)
      end
    end

    context 'without existing count records' do
      before do
        # Delete all existing count records to test the fallback
        RepresentationManagement::AccreditationApiEntityCount.destroy_all

        # Create actual database records for individuals that will be counted
        create_list(:accredited_individual, agents_count, :claims_agent)
        create_list(:accredited_individual, attorneys_count, :attorney)
        create_list(:accredited_individual, representatives_count, :representative)
        create_list(:accredited_organization, 5)
      end

      it 'falls back to individual counts if no latest record exists' do
        result = unpersisted_model.send(:get_counts_from_db)

        expect(result[:agents]).to eq(agents_count)
        expect(result[:attorneys]).to eq(attorneys_count)
        expect(result[:representatives]).to eq(representatives_count)
        expect(result[:veteran_service_organizations]).to eq(5)
      end
    end
  end

  describe '#percentage_change' do
    let(:model) { build(:accreditation_api_entity_count) }

    context 'when previous value is nil' do
      it 'returns 0.0' do
        result = model.send(:percentage_change, nil, 100)
        expect(result).to eq(0.0)
      end
    end

    context 'when previous value is zero' do
      it 'returns 0.0' do
        result = model.send(:percentage_change, 0, 100)
        expect(result).to eq(0.0)
      end
    end

    context 'when calculating positive changes (increases)' do
      it 'returns positive percentage for 20% increase' do
        result = model.send(:percentage_change, 100, 120)
        expect(result).to eq(20.0)
      end

      it 'returns positive percentage for large increase' do
        result = model.send(:percentage_change, 50, 100)
        expect(result).to eq(100.0)
      end
    end

    context 'when calculating negative changes (decreases)' do
      it 'returns negative percentage for 20% decrease' do
        result = model.send(:percentage_change, 100, 80)
        expect(result).to eq(-20.0)
      end

      it 'returns -100% for complete decrease to zero' do
        result = model.send(:percentage_change, 100, 0)
        expect(result).to eq(-100.0)
      end
    end

    context 'when values are equal' do
      it 'returns 0.0 for no change' do
        result = model.send(:percentage_change, 100, 100)
        expect(result).to eq(0.0)
      end
    end

    context 'when working with decimal results' do
      it 'rounds to 2 decimal places for precise calculations' do
        result = model.send(:percentage_change, 3, 4)
        expect(result).to eq(33.33) # (4-3)/3 * 100 = 33.333...
      end

      it 'handles fractional decreases properly' do
        result = model.send(:percentage_change, 7, 5)
        expect(result).to eq(-28.57) # (5-7)/7 * 100 = -28.571...
      end
    end

    context 'when working with edge cases' do
      it 'handles very small numbers' do
        result = model.send(:percentage_change, 1, 2)
        expect(result).to eq(100.0)
      end

      it 'handles large numbers' do
        result = model.send(:percentage_change, 1000, 1200)
        expect(result).to eq(20.0)
      end
    end
  end

  describe '#count_report' do
    let(:model) { build(:accreditation_api_entity_count) }

    before do
      allow(model).to receive(:log_error)
    end

    context 'when API and DB counts are available' do
      before do
        allow(model).to receive_messages(
          current_api_counts: {
            agents: 120,
            attorneys: 85,
            representatives: 95,
            veteran_service_organizations: 150
          },
          current_db_counts: {
            agents: 100,
            attorneys: 100,
            representatives: 100,
            veteran_service_organizations: 100
          }
        )
      end

      it 'generates a report with current counts, previous counts, and percentage changes' do
        report = model.count_report

        expect(report).to include('Accreditation API Entity Counts Report:')
        expect(report).to include('Agents: Current: 120, Previous: 100, Change: 20.0%')
        expect(report).to include('Attorneys: Current: 85, Previous: 100, Change: -15.0%')
        expect(report).to include('VSO Representatives: Current: 95, Previous: 100, Change: -5.0%')
        expect(report).to include('Veteran Service Organizations: Current: 150, Previous: 100, Change: 50.0%')
      end

      it 'includes all entity types in the report' do
        report = model.count_report

        described_class::TYPES.each do |type|
          expect(report).to include(described_class::TYPE_LABELS[type.to_sym])
        end
      end
    end

    context 'when counts show various percentage changes' do
      before do
        allow(model).to receive_messages(
          current_api_counts: {
            agents: 100,      # No change
            attorneys: 120,   # 20% increase
            representatives: 75, # 25% decrease
            veteran_service_organizations: 200 # 100% increase
          },
          current_db_counts: {
            agents: 100,
            attorneys: 100,
            representatives: 100,
            veteran_service_organizations: 100
          }
        )
      end

      it 'correctly calculates and displays percentage changes' do
        report = model.count_report

        expect(report).to include('Agents: Current: 100, Previous: 100, Change: 0.0%')
        expect(report).to include('Attorneys: Current: 120, Previous: 100, Change: 20.0%')
        expect(report).to include('VSO Representatives: Current: 75, Previous: 100, Change: -25.0%')
        expect(report).to include('Veteran Service Organizations: Current: 200, Previous: 100, Change: 100.0%')
      end
    end

    context 'when previous counts are nil or zero' do
      before do
        allow(model).to receive_messages(
          current_api_counts: {
            agents: 50,
            attorneys: 75,
            representatives: 25,
            veteran_service_organizations: 10
          },
          current_db_counts: {
            agents: nil,
            attorneys: 0,
            representatives: 100,
            veteran_service_organizations: 50
          }
        )
      end

      it 'handles nil and zero previous counts gracefully' do
        report = model.count_report

        expect(report).to include('Agents: Current: 50, Previous: , Change: 0.0%')
        expect(report).to include('Attorneys: Current: 75, Previous: 0, Change: 0.0%')
        expect(report).to include('VSO Representatives: Current: 25, Previous: 100, Change: -75.0%')
        expect(report).to include('Veteran Service Organizations: Current: 10, Previous: 50, Change: -80.0%')
      end
    end

    context 'when counts have decimal precision' do
      before do
        allow(model).to receive_messages(
          current_api_counts: {
            agents: 33,
            attorneys: 67,
            representatives: 34,
            veteran_service_organizations: 29
          },
          current_db_counts: {
            agents: 30,
            attorneys: 60,
            representatives: 35,
            veteran_service_organizations: 30
          }
        )
      end

      it 'rounds percentage changes to 2 decimal places' do
        report = model.count_report

        expect(report).to include('Agents: Current: 33, Previous: 30, Change: 10.0%')
        expect(report).to include('Attorneys: Current: 67, Previous: 60, Change: 11.67%')
        expect(report).to include('VSO Representatives: Current: 34, Previous: 35, Change: -2.86%')
        expect(report).to include('Veteran Service Organizations: Current: 29, Previous: 30, Change: -3.33%')
      end
    end

    context 'when an error occurs during report generation' do
      before do
        allow(model).to receive(:current_api_counts).and_raise(StandardError.new('API connection failed'))
      end

      it 'logs the error and returns nil' do
        result = model.count_report

        expect(model).to have_received(:log_error).with('Error generating count report: API connection failed')
        expect(result).to be_nil
      end
    end

    context 'when current_db_counts method fails' do
      before do
        allow(model).to receive(:current_api_counts).and_return({ agents: 100 })
        allow(model).to receive(:current_db_counts).and_raise(StandardError.new('Database error'))
      end

      it 'handles database errors gracefully' do
        result = model.count_report

        expect(model).to have_received(:log_error).with('Error generating count report: Database error')
        expect(result).to be_nil
      end
    end

    context 'when percentage_change method is called' do
      before do
        allow(model).to receive_messages(
          current_api_counts: { agents: 90 },
          current_db_counts: { agents: 100 }
        )
        allow(model).to receive(:percentage_change).and_call_original
      end

      it 'uses the percentage_change method for calculations' do
        model.count_report

        expect(model).to have_received(:percentage_change).with(100, 90)
      end
    end
  end
end
