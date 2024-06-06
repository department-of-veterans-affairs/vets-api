# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::TriageTeamSerializer do
  let(:triage_team) { build_stubbed(:triage_team) }

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

  it 'includes :relation_type' do
    expect(rendered_attributes[:relation_type]).to eq triage_team.relation_type
  end

  it 'includes :preferred_team' do
    expect(rendered_attributes[:preferred_team]).to eq triage_team.preferred_team
  end

end
