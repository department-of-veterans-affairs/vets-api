# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditationApiEntityCount, type: :model do
  let(:model) { create(:accreditation_api_entity_count) }
  # Using a constant we know exists in the code
  let(:allowed_types) { [:agents, :attorneys, :representatives, :veteran_service_organizations] }
  let(:decrease_threshold) { 0.20 } # Assuming this is the threshold value
  
  before do
    # Mock the ALLOWED_TYPES constant
    stub_const("#{described_class}::TYPES", allowed_types)
    stub_const("#{described_class}::DECREASE_THRESHOLD", decrease_threshold)
    
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
    expect {
      model.save_api_counts
    }.to change { model.reload.agents }.to(100)
      .and change { model.reload.attorneys }.to(100)
      .and change { model.reload.representatives }.to(100)
      .and change { model.reload.veteran_service_organizations }.to(100)
  end

    it 'only assigns values for valid counts' do
    allow(model).to receive(:valid_count?).with(:agents, notify: false).and_return(false)
    allow(model).to receive(:valid_count?).with(:attorneys, notify: false).and_return(true)
    allow(model).to receive(:valid_count?).with(:representatives, notify: false).and_return(true)
    allow(model).to receive(:valid_count?).with(:veteran_service_organizations, notify: false).and_return(false)
    
    model.save_api_counts
    model.reload
    
    expect(model.agents).not_to eq(100)
    expect(model.attorneys).to eq(100)
    expect(model.representatives).to eq(100)
    expect(model.veteran_service_organizations).not_to eq(100)
  end

    it 'persists the record' do
      model.save_api_counts
      expect(model).to be_persisted
    end

    it 'handles exceptions and logs errors' do
      allow(model).to receive(:save!).and_raise(StandardError.new('Test error'))
      
      model.save_api_counts
      
      expect(model).to have_received(:log_error).with("Error saving API counts: Test error")
    end
  end

  describe '#valid_count?' do
    let(:type) { :agents }
    
    before do
      allow(model).to receive(:current_db_counts).and_return({ agents: 100 })
      allow(model).to receive(:current_api_counts).and_return({ agents: 110 })
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
        allow(model).to receive(:current_db_counts).and_return({ agents: 100 })
        allow(model).to receive(:current_api_counts).and_return({ agents: 110 })
      end
      
      it 'returns true' do
        expect(model.valid_count?(type)).to be true
      end
    end
    
    context 'when new count is equal to previous count' do
      before do
        allow(model).to receive(:current_db_counts).and_return({ agents: 100 })
        allow(model).to receive(:current_api_counts).and_return({ agents: 100 })
      end
      
      it 'returns true' do
        expect(model.valid_count?(type)).to be true
      end
    end
    
    context 'when new count is less than previous count but within threshold' do
      before do
        allow(model).to receive(:current_db_counts).and_return({ agents: 100 })
        allow(model).to receive(:current_api_counts).and_return({ agents: 90 }) # 10% decrease
      end
      
      it 'returns true' do
        expect(model.valid_count?(type)).to be true
      end
    end
    
    context 'when new count is less than previous count and exceeds threshold' do
      before do
        allow(model).to receive(:current_db_counts).and_return({ agents: 100 })
        allow(model).to receive(:current_api_counts).and_return({ agents: 70 }) # 30% decrease
      end
      
      it 'returns false' do
        expect(model.valid_count?(type)).to be false
      end
      
      it 'calls notify_threshold_exceeded by default' do
        model.valid_count?(type)
        expect(model).to have_received(:notify_threshold_exceeded)
          .with(type, 100, 70, 0.3, decrease_threshold)
      end
      
      it 'skips notification when notify is false' do
        model.valid_count?(type, notify: false)
        expect(model).not_to have_received(:notify_threshold_exceeded)
      end
    end
  end
  
  describe '#notify_threshold_exceeded' do
    it 'logs to Slack with the correct message format' do
      model.send(:notify_threshold_exceeded, :agents, 100, 70, 0.3, 0.2)
      
      expected_message = "⚠️ AccreditationApiEntityCount Alert: Agents count decreased beyond threshold!\n" \
                        "Previous: 100\n" \
                        "New: 70\n" \
                        "Decrease: 30.0%\n" \
                        "Threshold: 20.0%\n" \
                        'Action: Update skipped, manual review required'
      
      expect(model).to have_received(:log_to_slack_threshold_channel).with(expected_message)
    end
    

  end

  describe '#get_counts_from_api' do
    let(:client) { instance_double("RepresentationManagement::GCLAWS::Client") }
    let(:response_body) { { 'totalRecords' => 100 } }
    let(:response) { instance_double("Response", body: response_body) }
    
    before do
      allow(RepresentationManagement::GCLAWS::Client).to receive(:get_accredited_entities)
        .and_return(response)
    end
    
    it 'fetches counts for each type from the API' do
      allowed_types.each do |type|
        expect(RepresentationManagement::GCLAWS::Client).to receive(  :get_accredited_entities)
          .with(type: type, page: 1, page_size:   1)
          .and_return(response)



      end
      
      result = model.send(:get_counts_from_api)
      
      allowed_types.each do |type|
        expect(result[type]).to eq(100)
      end
    end
    
    it 'handles API errors for individual types' do
      allow(RepresentationManagement::GCLAWS::Client).to receive(:get_accredited_entities)
        .with(type: :agents, page: 1, page_size: 1)
        .and_raise(StandardError.new("API error"))
      
      result = model.send(:get_counts_from_api)
      
      expect(model).to have_received(:log_error).with("Error fetching count for agents: API error")
      expect(result[:agents]).to be_nil
    end
  end
  
  describe '#get_counts_from_db' do
    let(:latest_count) { instance_double(described_class, 
      agents: 100, 
      attorneys: 200, 
      representatives: 300, 
      veteran_service_organizations: 50
    )}
    
    before do
      allow(described_class).to receive(:order).and_return([latest_count])
      allow(model).to receive(:individual_count).and_return(10)
      allow(AccreditedOrganization).to receive(:count).and_return(5)
    end
    
    it 'returns counts from the latest record if available' do
      result = model.send(:get_counts_from_db)
      
      expect(result[:agents]).to eq(100)
      expect(result[:attorneys]).to eq(200)
      expect(result[:representatives]).to eq(300)
      expect(result[:veteran_service_organizations]).to eq(50)
    end
    
    it 'falls back to individual counts if no latest record exists' do
      allow(described_class).to receive(:order).and_return([])
      
      result = model.send(:get_counts_from_db)
      
      expect(result[:agents]).to eq(10)
      expect(result[:attorneys]).to eq(10)
      expect(result[:representatives]).to eq(10)
      expect(result[:veteran_service_organizations]).to eq(5)
    end
  end
end
