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

  it 'includes :relationship_type' do
    expect(attributes['relationship_type']).to eq triage_team.relationship_type
  end
end
