# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')
require_relative '../../../../app/serializers/covid_research/volunteer/name_serializer'

RSpec.describe CovidResearch::Volunteer::NameSerializer do
  let(:subject) { described_class.new }
  let(:payload) do
    {
      'first' => 'Joe',
      'last' => 'Schmoe',
      'suffix' => 'II'
    }
  end

  describe '#serialize' do
    it 'modifies the first attribute' do
      expect(subject.serialize(payload)).to include({ QuestionName: 'firstName', QuestionValue: 'Joe' })
    end

    it 'modifies the last attribute' do
      expect(subject.serialize(payload)).to include({ QuestionName: 'lastName', QuestionValue: 'Schmoe' })
    end

    it 'preserves other attributes' do
      expect(subject.serialize(payload)).to include({ QuestionName: 'suffix', QuestionValue: 'II' })
    end
  end
end
