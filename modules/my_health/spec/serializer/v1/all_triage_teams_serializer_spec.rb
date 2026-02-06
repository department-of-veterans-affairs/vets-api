# frozen_string_literal: true

require 'rails_helper'
require_relative '../../factories/all_triage_teams'

describe MyHealth::V1::AllTriageTeamsSerializer, type: :serializer do
  subject { serialize(triage_team, serializer_class: described_class) }

  let(:triage_team) { build_stubbed(:all_triage_team) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq triage_team.triage_team_id.to_s
  end

  it 'includes :triage_team_id' do
    expect(attributes['triage_team_id']).to eq triage_team.triage_team_id
  end

  it 'includes :name' do
    expect(attributes['name']).to eq triage_team.name
  end

  it 'includes :station_number' do
    expect(attributes['station_number']).to eq triage_team.station_number
  end

  it 'includes :blocked_status' do
    expect(attributes['blocked_status']).to eq triage_team.blocked_status
  end

  it 'includes :preferred_team' do
    expect(attributes['preferred_team']).to eq triage_team.preferred_team
  end

  it 'includes :relation_type' do
    expect(attributes['relation_type']).to eq triage_team.relation_type
  end

  it 'includes :lead_provider_name' do
    expect(attributes['lead_provider_name']).to eq triage_team.lead_provider_name
  end

  it 'includes :location_name' do
    expect(attributes['location_name']).to eq triage_team.location_name
  end

  it 'includes :team_name' do
    expect(attributes['team_name']).to eq triage_team.team_name
  end

  it 'includes :suggested_name_display' do
    expect(attributes['suggested_name_display']).to eq triage_team.suggested_name_display
  end

  it 'includes :health_care_system_name' do
    expect(attributes['health_care_system_name']).to eq triage_team.health_care_system_name
  end

  it 'includes :group_type_enum_val' do
    expect(attributes['group_type_enum_val']).to eq triage_team.group_type_enum_val
  end

  it 'includes :sub_group_type_enum_val' do
    expect(attributes['sub_group_type_enum_val']).to eq triage_team.sub_group_type_enum_val
  end

  it 'includes :group_type_patient_display' do
    expect(attributes['group_type_patient_display']).to eq triage_team.group_type_patient_display
  end

  it 'includes :sub_group_type_patient_display' do
    expect(attributes['sub_group_type_patient_display']).to eq triage_team.sub_group_type_patient_display
  end

  it 'includes :oh_triage_group' do
    expect(attributes['oh_triage_group']).to eq triage_team.oh_triage_group
  end

  it 'includes :migrating_to_oh' do
    expect(attributes['migrating_to_oh']).to eq triage_team.migrating_to_oh
  end
end
