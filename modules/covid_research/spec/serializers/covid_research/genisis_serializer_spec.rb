# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')
require_relative '../../../app/serializers/covid_research/genisis_serializer'
# Because we aren't requiring the Rails helper so it isn't autoloaded
require_relative '../../../app/serializers/covid_research/volunteer/name_serializer'

RSpec.describe CovidResearch::GenisisSerializer do
  let(:subject)  { described_class.new }
  let(:payload)  { JSON.parse(read_fixture('valid-intake-submission.json')) }
  let(:expected) { JSON.parse(read_fixture('genisis-intake-mapping.json'))['expected'] }

  let(:update_payload)  { JSON.parse(read_fixture('valid-update-submission.json')) }
  let(:update_expected) { JSON.parse(read_fixture('genisis-update-mapping.json'))['expected'] }

  before do
    Timecop.freeze(Time.now.utc)
  end

  after do
    Timecop.return
  end

  describe '#serialize intake' do
    let(:output) { JSON.parse(subject.serialize(payload)) }

    it 'builds a valid payload' do
      expect(output['FormQuestions']).not_to be_empty
      expect(output['CreatedDateTime']).not_to be_empty
      expect(output['UpdatedDateTime']).not_to be_empty
    end

    it 'formats the times as iso8601' do
      expected = Time.now.utc.iso8601

      expect(output['CreatedDateTime']).to eq(expected.to_s)
    end

    it 'translates the json payload to a list of key value pairs' do
      expect(output['FormQuestions']).to eq(expected)
    end

    it 'translates false to "No"' do
      expect(output['FormQuestions'][3]['QuestionValue']).to eq 'No'
    end

    it 'translates true to "Yes"' do
      expect(output['FormQuestions'][6]['QuestionValue']).to eq 'Yes'
    end
  end

  describe '#serialize update' do
    let(:output) { JSON.parse(subject.serialize(update_payload)) }

    it 'builds a valid payload' do
      expect(output['FormQuestions']).not_to be_empty
      expect(output['CreatedDateTime']).not_to be_empty
      expect(output['UpdatedDateTime']).not_to be_empty
    end

    it 'formats the times as iso8601' do
      expected = Time.now.utc.iso8601

      expect(output['CreatedDateTime']).to eq(expected.to_s)
    end

    it 'translates the json payload to a list of key value pairs' do
      expect(output['FormQuestions']).to eq(update_expected)
    end

    it 'translates false to "No"' do
      expect(output['FormQuestions'][3]['QuestionValue']).to eq 'No'
    end

    it 'translates true to "Yes"' do
      expect(output['FormQuestions'][6]['QuestionValue']).to eq 'Yes'
    end
  end
end
