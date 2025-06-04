# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

describe UnifiedHealthData::Service, type: :service do
  subject { described_class }

  let(:user) { build(:user, :loa3) }
  let(:service) { described_class.new(user) }
  let(:sample_response) do
    JSON.parse(File.read(Rails.root.join(
      'spec', 'support', 'fixtures', 'unified_health_data', 'sample_response.json'
    )))
  end

  describe '#get_labs' do
    context 'with defensive nil checks' do
      it 'handles missing contained sections' do
        allow(service).to receive(:fetch_access_token).and_return('token')
        allow(service).to receive(:perform).and_return(double(body: sample_response))
        
        # Simulate missing contained by modifying the response
        modified_response = JSON.parse(sample_response.to_json)
        modified_response['vista']['entry'].first['resource']['contained'] = nil
        allow(service).to receive(:parse_response_body).and_return(modified_response)
        
        expect {
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs).to be_an(Array)
        }.not_to raise_error
      end
    end
  end

  # Individual method tests
  describe '#fetch_body_site' do
    context 'when contained is nil' do
      it 'returns an empty string' do
        resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/123' }] }
        contained = nil
        
        result = service.send(:fetch_body_site, resource, contained)
        
        expect(result).to eq('')
      end
    end
    
    context 'when basedOn is nil' do
      it 'returns an empty string' do
        resource = {}
        contained = [{ 'resourceType' => 'ServiceRequest', 'id' => '123' }]
        
        result = service.send(:fetch_body_site, resource, contained)
        
        expect(result).to eq('')
      end
    end
  end

  describe '#fetch_sample_tested' do
    context 'when contained is nil' do
      it 'returns an empty string' do
        record = { 'specimen' => { 'reference' => 'Specimen/123' } }
        contained = nil
        
        result = service.send(:fetch_sample_tested, record, contained)
        
        expect(result).to eq('')
      end
    end
    
    context 'when specimen is nil' do
      it 'returns an empty string' do
        record = {}
        contained = [{ 'resourceType' => 'Specimen', 'id' => '123' }]
        
        result = service.send(:fetch_sample_tested, record, contained)
        
        expect(result).to eq('')
      end
    end
  end

  describe '#fetch_observations' do
    context 'when contained is nil' do
      it 'returns an empty array' do
        record = { 'resource' => { 'contained' => nil } }
        
        result = service.send(:fetch_observations, record)
        
        expect(result).to eq([])
      end
    end
  end
  
  describe '#fetch_code' do
    context 'when category is nil' do
      it 'returns nil' do
        record = { 'resource' => { 'category' => nil } }
        
        result = service.send(:fetch_code, record)
        
        expect(result).to be_nil
      end
    end
    
    context 'when category is empty' do
      it 'returns nil' do
        record = { 'resource' => { 'category' => [] } }
        
        result = service.send(:fetch_code, record)
        
        expect(result).to be_nil
      end
    end
  end
  
  describe '#fetch_observation_value' do
    context 'when observation is nil' do
      it 'returns nil text and type' do
        result = service.send(:fetch_observation_value, nil)
        
        expect(result).to eq({ text: nil, type: nil })
      end
    end
  end
  
  describe '#parse_single_record' do
    context 'when record is nil' do
      it 'returns nil' do
        result = service.send(:parse_single_record, nil)
        
        expect(result).to be_nil
      end
    end
    
    context 'when resource is nil' do
      it 'returns nil' do
        record = {}
        
        result = service.send(:parse_single_record, record)
        
        expect(result).to be_nil
      end
    end
  end
  
  describe '#parse_labs' do
    context 'when records is nil' do
      it 'returns an empty array' do
        result = service.send(:parse_labs, nil)
        
        expect(result).to eq([])
      end
    end
    
    context 'when records is empty' do
      it 'returns an empty array' do
        result = service.send(:parse_labs, [])
        
        expect(result).to eq([])
      end
    end
  end
  
  describe '#fetch_combined_records' do
    context 'when body is nil' do
      it 'returns an empty array' do
        result = service.send(:fetch_combined_records, nil)
        
        expect(result).to eq([])
      end
    end
  end
end
