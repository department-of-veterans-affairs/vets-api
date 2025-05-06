# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::QuestionnaireFormatter do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of subject' do
      expect(subject.build([])).to be_a(HealthQuest::QuestionnaireManager::QuestionnaireFormatter)
    end
  end

  describe 'attributes' do
    it 'responds to questionnaires_array' do
      expect(subject.build([]).respond_to?(:questionnaires_array)).to be(true)
    end
  end

  describe '#to_h' do
    let(:quest) { double('Questionnaire') }
    let(:quest_array) { [quest] }

    before do
      allow_any_instance_of(subject).to receive(:use_contexts).and_return([])
      allow_any_instance_of(subject).to receive(:value_codeable_concepts).and_return([])
      allow_any_instance_of(subject).to receive(:codes).and_return(['543/123456'])
    end

    it 'builds a formatted hash' do
      expect(subject.build(quest_array).to_h).to eq({ '543/123456' => [quest] })
    end
  end

  describe '#use_contexts' do
    let(:quest) { double('Questionnaire', to_hash: { 'resource' => { 'useContext' => [] } }) }

    it 'returns an array' do
      expect(subject.build([]).use_contexts(quest)).to be_a(Array)
    end
  end

  describe '#codes' do
    let(:vcc) { [{ 'code' => '543/123456' }] }

    it 'returns an array' do
      expect(subject.build([]).codes(vcc)).to eq(['543/123456'])
    end
  end

  describe '#value_codeable_concepts' do
    let(:use_contexts) { [{ 'valueCodeableConcept' => { 'coding' => [] } }] }

    it 'is an array' do
      expect(subject.build([]).value_codeable_concepts(use_contexts)).to be_a(Array)
    end
  end
end
