# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')
require_relative '../../../../app/services/covid_research/volunteer/form_service'
require_relative '../../../../lib/redis_format' # No Rails helper no auto-load

# TODO: Confirm this test case is doing what it should

RSpec.describe CovidResearch::Volunteer::FormService do
  subject { described_class.new('COVID-VACCINE-TRIAL-UPDATE') }

  let(:valid)   { JSON.parse(read_fixture('valid-update-submission.json')) }
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
        expect(subject.valid!(valid)).to be(true)
      end

      it 'raises an exception if the JSON is invalid' do
        expect { subject.valid!(invalid) }.to raise_exception(described_class::SchemaValidationError)
      end
    end

    describe '#submission_errors' do
      it 'returns a list of error objects if the JSON is invalid' do
        expect(subject.submission_errors(invalid)).not_to be_empty
      end

      it 'returns an empty list if they JSON is valid' do
        expect(subject.submission_errors(valid)).to be_empty
      end
    end
  end

  context 'genISIS delivery' do
    describe '#queue_delivery' do
      let(:subject)       { described_class.new('COVID-VACCINE-TRIAL-UPDATE', worker_double) }
      let(:worker_double) { double('worker', perform_async: true) }
      let(:redis_format)  { 'redis' }
      let(:encrypted)     { 'encrypted' } # For sanity, it doesn't really matter

      let(:submission) do
        { 'submission' => 'data' }
      end

      before do
        allow_any_instance_of(CovidResearch::RedisFormat).to receive(:to_json).and_return(encrypted)
      end

      it 'converts the submission to the RedisFormat' do
        expect_any_instance_of(CovidResearch::RedisFormat).to receive(:form_data=)

        subject.queue_delivery(submission)
      end

      it 'schedules the submission for delivery to genISIS' do
        allow_any_instance_of(CovidResearch::RedisFormat).to receive(:form_data=).and_return(submission)
        expect(worker_double).to receive(:perform_async).with(encrypted)

        subject.queue_delivery(submission)
      end
    end
  end
end
