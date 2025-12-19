# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/immunization_adapter'
require 'unified_health_data/models/immunization'

RSpec.describe 'ImmunizationAdapter' do
  let(:adapter) { UnifiedHealthData::Adapters::ImmunizationAdapter.new }
  let(:vaccine_sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'immunizations_sample.json'
    ).read)
  end

  before do
    allow(UnifiedHealthData::Immunization).to receive(:new).and_call_original
  end

  describe '#parse_single_immunization' do
    it 'returns the expected fields for happy path for vista immunization with all fields' do
      vista_single_record = vaccine_sample_response['vista']['entry'][0]
      # This also checks fallbacks and nil guards since VistA data is missing many fields
      parsed_immunization = adapter.parse_single_immunization(vista_single_record)

      expect(parsed_immunization).to have_attributes(
        {
          'id' => '431b45a9-9070-4f8c-8de5-ab9cf9403fce',
          'cvx_code' => 90732,
          'date' => '2024-11-26T20:35:00Z',
          'dose_number' => 'SERIES 1',
          'dose_series' => 'SERIES 1',
          'group_name' => 'PNEUMOCOCCAL POLYSACCHARIDE PPV23',
          'location' => 'NUCLEAR MED',
          'location_id' => nil,
          'manufacturer' => nil,
          'note' => nil,
          'reaction' => nil,
          'short_description' => 'PNEUMOCOCCAL POLYSACCHARIDE PPV23',
          'administration_site' => 'LEFT DELTOID',
          'lot_number' => nil,
          'status' => 'completed'
        }
      )
    end

    it 'returns the expected fields for happy path for OH immunization with all fields' do
      parsed_immunization = adapter.parse_single_immunization(vaccine_sample_response['oracle-health']['entry'][0])

      expect(parsed_immunization).to have_attributes(
        {
          'id' => 'M20875183434',
          'cvx_code' => 140,
          'date' => '2025-12-10T16:20:00-06:00',
          'dose_number' => 'Unknown',
          'dose_series' => 'Unknown',
          'group_name' => 'Influenza',
          'location' => '556 Captain James A Lovell IL VA Medical Center',
          'location_id' => '353977013',
          'manufacturer' => 'Seqirus USA Inc',
          'note' => 'Added comment "note"',
          'reaction' => nil,
          'short_description' => 'influenza virus vaccine, inactivated',
          'administration_site' => 'Shoulder, left (deltoid)',
          'lot_number' => 'AX5586C',
          'status' => 'completed'
        }
      )
    end
  end
end
