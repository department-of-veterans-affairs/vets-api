# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/allergy_adapter'
require 'unified_health_data/models/allergy'

RSpec.describe 'AllergyAdapter' do
  let(:adapter) { UnifiedHealthData::Adapters::AllergyAdapter.new }
  let(:allergy_sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'allergies_example.json'
    ).read)
  end

  before do
    allow(UnifiedHealthData::Allergy).to receive(:new).and_call_original
  end

  describe '#parse_single_allergy' do
    it 'returns the expected fields for happy path for vista allergy with all fields' do
      vista_single_record = allergy_sample_response['vista']['entry'][0]
      # This normally happens in the service, but we need the id for the test so we're mocking it here
      vista_identifier = vista_single_record['resource']['identifier'].find { |id| id['system'].starts_with?('https://va.gov/systems/') }
      vista_single_record['resource']['id'] = vista_identifier['value']
      # This also checks fallbacks and nil guards since VistA data is missing many fields
      parsed_allergy = adapter.parse_single_allergy(vista_single_record)

      expect(parsed_allergy).to have_attributes(
        {
          'id' => '2678',
          'name' => 'TRAZODONE',
          'date' => nil,
          'categories' => ['medication'],
          'reactions' => [],
          'location' => nil, # Neither OH nor VistA samples have location names
          'observedHistoric' => 'h',
          'notes' => [],
          'provider' => nil
        }
      )
    end

    it 'returns the expected fields for happy path for OH allergy with all fields' do
      parsed_allergy = adapter.parse_single_allergy(allergy_sample_response['oracle-health']['entry'][0])

      expect(parsed_allergy).to have_attributes(
        {
          'id' => '132892323',
          'name' => 'Penicillin',
          'date' => '2002',
          'categories' => ['medication'],
          'reactions' => ['Urticaria (Hives)', 'Sneezing'],
          'location' => nil, # Neither OH nor VistA samples have location names
          'observedHistoric' => nil, # OH data does not have this field
          'notes' => ['Patient reports adverse reaction to previously prescribed pencicillins'],
          'provider' => ' Victoria A Borland'
        }
      )
    end
  end
end
