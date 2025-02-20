# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::ResourceHashIdFormatter do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of subject' do
      expect(subject.build([])).to be_a(HealthQuest::QuestionnaireManager::ResourceHashIdFormatter)
    end
  end

  describe 'attributes' do
    it 'responds to resource_array' do
      expect(subject.build([]).respond_to?(:resource_array)).to be(true)
    end
  end

  describe '#to_h' do
    let(:foo) { double('Foo', resource: double('Resource', id: 'I2-ABC123')) }
    let(:foo_array) { [foo] }

    it 'builds a formatted hash' do
      expect(subject.build(foo_array).to_h).to eq({ 'I2-ABC123' => foo })
    end
  end
end
