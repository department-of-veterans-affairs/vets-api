# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::OrganizationFormatter do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of subject' do
      expect(subject.build([])).to be_a(HealthQuest::QuestionnaireManager::OrganizationFormatter)
    end
  end

  describe 'attributes' do
    it 'responds to orgs_array' do
      expect(subject.build([]).respond_to?(:orgs_array)).to eq(true)
    end
  end

  describe '#to_h' do
    let(:org) do
      double('Organization', resource: double('Resource',
                                              identifier: [double('first'), double('last', value: 'vha_333')]))
    end
    let(:orgs_array) { [org] }

    it 'builds a formatted hash' do
      expect(subject.build(orgs_array).to_h).to eq({ 'vha_333' => org })
    end
  end
end
