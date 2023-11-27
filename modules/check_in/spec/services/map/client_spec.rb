# frozen_string_literal: true

require 'rails_helper'

describe Map::Client do
  subject { described_class.build }

  describe '.build' do
    it 'returns an instance of described_class' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe 'extends' do
    it 'extends forwardable' do
      expect(described_class.ancestors).to include(Forwardable)
    end
  end

  describe '#initialize' do
    it 'has settings attribute' do
      expect(subject.settings).to be_a(Config::Options)
    end
  end
end
