# frozen_string_literal: true

require 'rails_helper'
require_relative '../../factories/all_triage_teams'

describe MyHealth::V1::AllTriageTeamsSerializer do
  let(:triage_team) { build_stubbed(:all_triage_team) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(triage_team, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq triage_team.triage_team_id.to_s
  end

  it 'includes :triage_team_id' do
    expect(rendered_attributes[:triage_team_id]).to eq triage_team.triage_team_id
  end

  it 'includes :name' do
    expect(rendered_attributes[:name]).to eq triage_team.name
  end

  it 'includes :station_number' do
    expect(rendered_attributes[:station_number]).to eq triage_team.station_number
  end

  it 'includes :blocked_status' do
    expect(rendered_attributes[:blocked_status]).to eq triage_team.blocked_status
  end

  it 'includes :preferred_team' do
    expect(rendered_attributes[:preferred_team]).to eq triage_team.preferred_team
  end

  it 'includes :relationship_type' do
    expect(rendered_attributes[:relationship_type]).to eq triage_team.relationship_type
  end
end
