# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TriageTeamSerializer, type: :serializer do
  let(:triage_team) { build :triage_team }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(triage_team, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id'].to_i).to eq(triage_team.triage_team_id)
  end

  it 'should include triage_team_id' do
    expect(attributes['triage_team_id'].to_i).to eq(triage_team.triage_team_id)
  end

  it "should include the team's name" do
    expect(attributes['name']).to eq(triage_team.name)
  end

  it "should include the team's patient relationship type" do
    expect(attributes['relation_type']).to eq(triage_team.relation_type)
  end
end
