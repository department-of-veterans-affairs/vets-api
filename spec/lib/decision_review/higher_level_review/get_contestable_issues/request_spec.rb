# frozen_string_literal: true

require_relative '../../../../../lib/decision_review/request.rb'
require_relative '../../../../../lib/decision_review/higher_level_review/get_contestable_issues/request.rb'
require_relative '../../../../../lib/decision_review/request_schema_error.rb'
require_relative '../../../../../lib/decision_review/schema_error.rb'
require 'rails_helper'

describe DecisionReview::HigherLevelReview::GetContestableIssues::Request do
  let(:data) { Struct.new(:headers, :benefit_type).new headers, benefit_type }

  let(:headers) do
    {
      'X-VA-SSN' => '123456789',
      'X-VA-Receipt-Date' => '1970-01-01'
    }
  end

  let(:benefit_type) { 'compensation' }

  describe '#initialize' do
    it 'creates a request object when given valid input' do
      expect(described_class.new(data)).to be_truthy
    end
  end

  describe '#schema_errors' do
    subject do
      described_class.new(data)
    rescue => e
      e
    end

    let(:benefit_type) { 'Hello!' }

    it 'throws a RequestSchemaError' do
      expect(subject).to be_a DecisionReview::RequestSchemaError
    end

    it 'has errors' do
      expect(subject.errors).to be_a Array
      expect(subject.errors).not_to be_empty
    end
  end

  describe '#perform_args' do
    subject { described_class.new(data) }

    it 'returns the arguments needed for the perform method' do
      expect(subject.perform_args).to be_an Array
      expect(subject.perform_args.second).to include(subject.data.benefit_type)
      expect(subject.perform_args.fourth).to eq subject.data.headers
    end
  end
end
