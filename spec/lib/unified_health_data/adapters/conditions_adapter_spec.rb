# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/conditions_adapter'

RSpec.describe UnifiedHealthData::Adapters::ConditionsAdapter, type: :service do
  let(:adapter) { UnifiedHealthData::Adapters::ConditionsAdapter.new }
  let(:conditions_sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'conditions_sample_response.json'
    ).read)
  end

  before do
    allow(UnifiedHealthData::Condition).to receive(:new).and_call_original
  end

  describe '#parse' do
    it 'returns the expected fields for vista condition with all fields' do
      vista_records = conditions_sample_response['vista']['entry'].map do |r|
        r.merge('source' => 'vista')
      end
      parsed_conditions = adapter.parse(vista_records)
      expect(parsed_conditions.size).to eq(16)

      expect(parsed_conditions).to all(have_attributes(
                                         id: be_a(String),
                                         name: be_a(String),
                                         date: be_a(String).or(be_nil),
                                         provider: be_a(String),
                                         facility: be_a(String),
                                         comments: be_an(Array),
                                         source: 'vista'
                                       ))
    end

    it 'returns the expected fields for oracle-health condition with all fields' do
      oh_records = conditions_sample_response['oracle-health']['entry'].map do |r|
        r.merge('source' => 'oracle-health')
      end
      parsed_conditions = adapter.parse(oh_records)

      expect(conditions_sample_response['oracle-health']['entry'].size).to be > parsed_conditions.size
      expect(parsed_conditions.size).to eq(2)
      expect(parsed_conditions).to all(have_attributes(
                                         id: be_a(String),
                                         name: be_a(String),
                                         date: be_a(String).or(be_nil),
                                         provider: be_a(String),
                                         facility: be_a(String),
                                         comments: be_an(Array),
                                         source: 'oracle-health'
                                       ))
    end

    it 'returns the expected fields with VistA sample data' do
      vista_records = conditions_sample_response['vista']['entry']
      # First VistA condition with all fields
      parsed_condition = adapter.parse_single_condition(vista_records[3].merge('source' => 'vista'))

      expect(parsed_condition).to have_attributes(
        id: '6f5683ba-2ae8-4d8d-85ff-24babcfbabde',
        name: 'Carcinoma in situ of skin, unspecified',
        date: '2024-01-03T04:00:00Z',
        provider: 'MCGUIRE,MARCI P',
        facility: 'CHYSHR TEST LAB',
        comments: ['Carcinoma of right ear'],
        source: 'vista'
      )
    end

    it 'returns the expected fields with Oracle Health sample data' do
      oh_records = conditions_sample_response['oracle-health']['entry']
      parsed_condition = adapter.parse_single_condition(oh_records[1].merge('source' => 'oracle-health'))

      expect(parsed_condition).to have_attributes(
        id: 'p1533314061',
        name: 'Disease caused by 2019-nCoV',
        date: '2025-01-20',
        provider: 'SYSTEM, SYSTEM Cerner, Cerner Managed Acct',
        facility: 'WAMC Bariatric Surgery',
        comments: ['This problem was added by Discern Expert for positive COVID-19 lab test.'],
        source: 'oracle-health'
      )
    end

    it 'handles empty records gracefully' do
      parsed_conditions = adapter.parse([])
      expect(parsed_conditions).to eq([])
    end
  end

  describe 'filtering by clinical status' do
    context 'with filtering enabled (default)' do
      it 'filters out conditions with non-active clinical status' do
        records = [
          {
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '1',
              'onsetDateTime' => '2024-01-15',
              'clinicalStatus' => {
                'coding' => [{ 'code' => 'resolved' }]
              },
              'code' => {
                'coding' => [{ 'display' => 'Resolved Condition' }]
              }
            }
          }
        ]

        expect(adapter.parse(records)).to eq([])
      end

      it 'filters out conditions with missing clinical status' do
        records = [
          {
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '1',
              'onsetDateTime' => '2024-01-15',
              'code' => {
                'coding' => [{ 'display' => 'Condition Without Status' }]
              }
              # Missing clinicalStatus
            }
          }
        ]

        expect(adapter.parse(records)).to eq([])
      end

      it 'includes conditions with active clinical status' do
        records = [
          {
            'source' => 'vista',
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '1',
              'onsetDateTime' => '2024-01-15',
              'clinicalStatus' => {
                'coding' => [{ 'code' => 'active' }]
              },
              'code' => {
                'coding' => [{ 'display' => 'Active Condition' }]
              }
            }
          }
        ]

        result = adapter.parse(records)
        expect(result.length).to eq(1)
        expect(result.first.name).to eq('Active Condition')
        expect(result.first.date).to eq('2024-01-15')
        expect(result.first.id).to eq('1')
        expect(result.first.source).to eq('vista')
      end

      it 'filters mixed active and inactive conditions' do
        records = [
          {
            'source' => 'vista',
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '1',
              'onsetDateTime' => '2024-01-15',
              'clinicalStatus' => {
                'coding' => [{ 'code' => 'active' }]
              },
              'code' => {
                'coding' => [{ 'display' => 'Active Condition' }]
              }
            }
          },
          {
            'source' => 'vista',
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '2',
              'onsetDateTime' => '2024-01-10',
              'clinicalStatus' => {
                'coding' => [{ 'code' => 'resolved' }]
              },
              'code' => {
                'coding' => [{ 'display' => 'Resolved Condition' }]
              }
            }
          },
          {
            'source' => 'oracle-health',
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '3',
              'recordedDate' => '2024-01-20',
              'clinicalStatus' => {
                'coding' => [{ 'code' => 'active' }]
              },
              'code' => {
                'coding' => [{ 'display' => 'Another Active Condition' }]
              }
            }
          },
          {
            'source' => 'vista',
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '4',
              'onsetDateTime' => '2024-01-05',
              'code' => {
                'coding' => [{ 'display' => 'No Status Condition' }]
              }
            }
          },
          {
            'source' => 'oracle-health',
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '5',
              'clinicalStatus' => {
                'coding' => [{ 'code' => 'active' }]
              },
              'code' => {
                'coding' => [{ 'display' => 'No Date Condition' }]
              }
            }
          }
        ]

        result = adapter.parse(records)
        expect(result.length).to eq(3)
        expect(result.map(&:name)).to contain_exactly('Active Condition', 'Another Active Condition',
                                                      'No Date Condition')
        expect(result.map(&:source)).to contain_exactly('vista', 'oracle-health', 'oracle-health')
      end
    end

    context 'with filtering disabled' do
      it 'includes conditions with any clinical status when filter_by_status is false' do
        records = [
          {
            'source' => 'vista',
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '1',
              'onsetDateTime' => '2024-01-15',
              'clinicalStatus' => {
                'coding' => [{ 'code' => 'resolved' }]
              },
              'code' => {
                'coding' => [{ 'display' => 'Resolved Condition' }]
              }
            }
          },
          {
            'source' => 'oracle-health',
            'resource' => {
              'resourceType' => 'Condition',
              'id' => '2',
              'onsetDateTime' => '2024-01-20',
              'clinicalStatus' => {
                'coding' => [{ 'code' => 'active' }]
              },
              'code' => {
                'coding' => [{ 'display' => 'Active Condition' }]
              }
            }
          }
        ]

        result = adapter.parse(records, filter_by_status: false)
        expect(result.length).to eq(2)
        expect(result.map(&:name)).to contain_exactly('Resolved Condition', 'Active Condition')
        expect(result.map(&:source)).to contain_exactly('vista', 'oracle-health')
      end
    end

    context 'with parse_single_condition' do
      it 'returns nil for condition with inactive status' do
        record = {
          'resource' => {
            'resourceType' => 'Condition',
            'id' => '1',
            'onsetDateTime' => '2024-01-15',
            'clinicalStatus' => {
              'coding' => [{ 'code' => 'inactive' }]
            },
            'code' => {
              'coding' => [{ 'display' => 'Test' }]
            }
          }
        }

        expect(adapter.parse_single_condition(record)).to be_nil
      end

      it 'returns condition object for active condition' do
        record = {
          'source' => 'vista',
          'resource' => {
            'resourceType' => 'Condition',
            'id' => '1',
            'onsetDateTime' => '2024-01-15',
            'clinicalStatus' => {
              'coding' => [{ 'code' => 'active' }]
            },
            'code' => {
              'coding' => [{ 'display' => 'Active Test' }]
            }
          }
        }

        result = adapter.parse_single_condition(record)
        expect(result).not_to be_nil
        expect(result.name).to eq('Active Test')
        expect(result.date).to eq('2024-01-15')
        expect(result.id).to eq('1')
        expect(result.source).to eq('vista')
      end

      it 'returns condition object regardless of clinical status when filter_by_status is false' do
        record = {
          'source' => 'oracle-health',
          'resource' => {
            'resourceType' => 'Condition',
            'id' => '1',
            'onsetDateTime' => '2024-01-15',
            'clinicalStatus' => {
              'coding' => [{ 'code' => 'resolved' }]
            },
            'code' => {
              'coding' => [{ 'display' => 'Resolved Test' }]
            }
          }
        }

        result = adapter.parse_single_condition(record, filter_by_status: false)
        expect(result).not_to be_nil
        expect(result.name).to eq('Resolved Test')
        expect(result.date).to eq('2024-01-15')
        expect(result.source).to eq('oracle-health')
      end
    end
  end
end
