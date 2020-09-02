# frozen_string_literal: true

require_relative '../../../../../lib/decision_review/response.rb'
require_relative '../../../../../lib/decision_review/higher_level_review/create/response.rb'
require_relative '../../../../../lib/decision_review/response_schema_error.rb'
require_relative '../../../../../lib/decision_review/schema_error.rb'
require 'rails_helper'

describe DecisionReview::HigherLevelReview::Create::Response do
  let(:response) { Struct.new(:status, :body).new status, body }
  let(:body) { VetsJsonSchema::EXAMPLES["HLR-CREATE-RESPONSE-#{status}"] }
  let(:status) { 200 }

  context 'successful response' do
    describe '#initialize' do
      it 'creates a request object when given valid input' do
        expect(described_class.new(response)).to be_truthy
      end
    end
  end

  context 'unsuccessful response' do
    let(:status) { 422 }

    describe '#initialize' do
      it 'creates a request object when given valid input' do
        expect(described_class.new(response)).to be_truthy
      end
    end
  end

  context 'unrecognized response' do
    describe '#schema_errors' do
      subject do
        described_class.new(response)
      rescue => e
        e
      end

      context 'unrecognized body' do
        let(:body) { '0' }

        it 'throws a ResponseSchemaError' do
          expect(subject).to be_a DecisionReview::ResponseSchemaError
        end

        it 'has errors' do
          expect(subject.errors).to be_a Array
          expect(subject.errors).not_to be_empty
        end
      end

      context 'unrecognized status' do
        let(:status) { 0 }

        it 'throws a ResponseSchemaError' do
          expect(subject).to be_a DecisionReview::ResponseSchemaError
        end

        it 'has errors' do
          expect(subject.errors).to be_a Array
          expect(subject.errors).not_to be_empty
        end
      end
    end
  end
end
