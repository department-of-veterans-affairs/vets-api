# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AllTriageTeams, type: :model do
  subject { described_class.new }

  describe 'attributes' do
    it 'has the expected attributes' do
      expect(subject.attributes.keys).to include(
        'triage_team_id',
        'name',
        'station_number',
        'blocked_status',
        'preferred_team',
        'relation_type',
        'lead_provider_name',
        'location_name',
        'team_name',
        'suggested_name_display',
        'health_care_system_name',
        'group_type_enum_val',
        'sub_group_type_enum_val',
        'group_type_patient_display',
        'sub_group_type_patient_display',
        'oh_triage_group'
      )
    end

    it 'has default values for boolean attributes' do
      expect(subject.blocked_status).to be false
      expect(subject.preferred_team).to be false
    end
  end

  describe 'sorting' do
    it 'has default sort configured' do
      # The model has default_sort_by name: :asc configured
      expect(described_class.instance_variable_get(:@default_sort_criteria)).to eq(name: :asc)
    end
  end

  describe 'vets model' do
    it 'includes Vets::Model module' do
      expect(described_class.included_modules).to include(Vets::Model)
    end
  end
end
