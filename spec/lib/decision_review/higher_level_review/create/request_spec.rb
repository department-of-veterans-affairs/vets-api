# frozen_string_literal: true

require_relative '../../../../../lib/decision_review/request.rb'
require_relative '../../../../../lib/decision_review/higher_level_review/create/request.rb'
require_relative '../../../../../lib/decision_review/request_schema_error.rb'
require_relative '../../../../../lib/decision_review/schema_error.rb'
require 'rails_helper'

describe DecisionReview::HigherLevelReview::Create::Request do
  let(:data) { Struct.new(:headers, :body).new headers, body }

  let(:headers) { VetsJsonSchema::EXAMPLES['HLR-CREATE-REQUEST-HEADERS'] }

  let(:body) { VetsJsonSchema::EXAMPLES['HLR-CREATE-REQUEST-BODY'] }

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

    let(:body) { 'Hi!' }

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
      expect(subject.perform_args.third).to eq subject.data.body
      expect(subject.perform_args.fourth).to eq subject.data.headers
    end
  end
end
