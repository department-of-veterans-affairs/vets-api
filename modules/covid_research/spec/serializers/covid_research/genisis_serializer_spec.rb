# frozen_string_literal: true

require 'spec_helper'
require_relative '../../covid_research_spec_helper.rb'
require_relative '../../../app/serializers/covid_research/genisis_serializer.rb'
# Because we aren't requiring the Rails helper so it isn't autoloaded
require_relative '../../../app/serializers/covid_research/volunteer/name_serializer.rb'

RSpec.configure do |c|
  c.include CovidResearchSpecHelper
end

RSpec.describe CovidResearch::GenisisSerializer do
  let(:subject)  { described_class.new }
  let(:payload)  { JSON.parse(read_fixture('valid-submission.json')) }
  let(:expected) { JSON.parse(read_fixture('genisis-mapping.json'))['expected'] }

  describe '#serialize' do
    let(:output) { JSON.parse(subject.serialize(payload)) }

    it 'builds a valid payload' do
      expect(output['FormQuestions']).not_to be_empty
      expect(output['CreatedDateTime']).not_to be_empty
      expect(output['UpdatedDateTime']).not_to be_empty
    end

    it 'translates the json payload to a list of key value pairs' do
      expect(output['FormQuestions']).to eq(expected)
    end

    it 'translates true to "Yes"' do
      expect(output['FormQuestions'].first['QuestionValue']).to eq 'No'
    end

    it 'translates false to "No"' do
      expect(output['FormQuestions'][5]['QuestionValue']).to eq 'Yes'
    end
  end
end
