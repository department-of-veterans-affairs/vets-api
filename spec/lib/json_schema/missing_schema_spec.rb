# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/json_schema/missing_schema'

describe JsonSchema::MissingSchema do
  let(:missing_schema_error) { described_class.new missing_key, keys }

  describe '#message' do
    subject { missing_schema_error.message }

    let(:missing_key) { nil }
    let(:keys) { %w[dog mouse cat parrot] }

    it('describes the error') do
      expect(subject).to eq 'schema <nil> not found. schemas: ["cat", "dog", "mouse", "parrot"]'
    end

    context 'performs no logic' do
      let(:missing_key) { 1 }
      let(:keys) { [4, 3, 2, 1] }

      it('describes the error') do
        expect(subject).to eq 'schema <1> not found. schemas: [1, 2, 3, 4]'
      end
    end
  end
end
