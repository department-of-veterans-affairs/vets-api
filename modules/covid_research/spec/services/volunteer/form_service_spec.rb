# frozen_string_literal: true

require_relative '../../../app/services/covid_research/volunteer/form_service.rb'
require_relative '../../covid_research_spec_helper.rb'

RSpec.configure do |c|
  c.include CovidResearchSpecHelper
end

RSpec.describe CovidResearch::Volunteer::FormService do
  let(:valid)   { JSON.parse(read_fixture('valid-submission.json')) }
  let(:invalid) { JSON.parse(read_fixture('no-name-submission.json')) }

  context 'JSON Schema validation' do
    describe '#valid?' do
      it 'returns true if the JSON is valid' do
        expect(subject.valid?(valid)).to be(true)
      end

      it 'returns false if the JSON is invalid' do
        expect(subject.valid?(invalid)).to be(false)
      end
    end

    describe '#valid!' do
      it 'returns true if the JSON is valid' do
        expect { subject.valid!(valid) }.not_to raise_exception
        expect(subject.valid!(valid)).to be (true)
      end

      it 'raises an exception if the JSON is invalid' do
        expect { subject.valid!(invalid) }.to raise_exception(described_class::SchemaValidationError)
      end
    end

    describe '#submission_errors' do
      it 'returns a list of error objects if the JSON is invalid' do
        expect(subject.submission_errors(invalid).length).to be > 0
      end

      it 'returns an empty list if they JSON is valid' do
        expect(subject.submission_errors(valid)).to be_empty()
      end
    end
  end
end