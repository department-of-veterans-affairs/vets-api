# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TriageTeamSerializer, type: :serializer do
  subject { serialize(triage_team, serializer_class: described_class) }

  let(:triage_team) { build(:triage_team) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id'].to_i).to eq(triage_team.triage_team_id)
  end

  it 'includes :type' do
    expect(data['type']).to eq('triage_teams')
  end

  it 'includes triage_team_id' do
    expect(attributes['triage_team_id']).to eq(triage_team.triage_team_id)
  end

  it "includes the team's name" do
    expect(attributes['name']).to eq(triage_team.name)
  end

  it "includes the team's patient relationship type" do
    expect(attributes['relation_type']).to eq(triage_team.relation_type)
  end

  it "includes the team's preferred team" do
    expect(attributes['preferred_team']).to eq(triage_team.preferred_team)
  end
end
