# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TriageTeam do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :triage_team, triage_team_id: 100 }
    let(:other) { described_class.new(attributes_for(:triage_team, triage_team_id: 101)) }

    it 'populates attributes' do
      expect(described_class.attribute_set.map(&:name)).to contain_exactly(:triage_team_id, :name, :relation_type)
      expect(subject.triage_team_id).to eq(params[:triage_team_id])
      expect(subject.name).to eq(params[:name])
      expect(subject.relation_type).to eq(params[:relation_type])
    end

    it 'can be compared by name' do
      expect(subject <=> other).to eq(-1)
      expect(other <=> subject).to eq(1)
    end
  end
end
