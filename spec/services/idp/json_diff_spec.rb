# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idp::JsonDiff do
  describe '#call' do
    subject(:result) { described_class.new(lhs:, rhs:).call }

    context 'when payloads are equal' do
      let(:lhs) { { first_name: 'Ada', details: { city: 'Boston' }, tags: [1, 2] } }
      let(:rhs) { { first_name: 'Ada', details: { city: 'Boston' }, tags: [1, 2] } }

      it 'returns no differences' do
        expect(result).to eq(
          is_different: false,
          diff: []
        )
      end
    end

    context 'when payloads differ at scalar fields' do
      let(:lhs) { { first_name: 'jee', last_name: 'doe' } }
      let(:rhs) { { first_name: 'john', last_name: 'doe' } }

      it 'returns only the changed field' do
        expect(result).to eq(
          is_different: true,
          diff: [
            { 'first_name' => { lhs: 'jee', rhs: 'john', is_different: true } }
          ]
        )
      end
    end

    context 'when nested objects and arrays differ' do
      let(:lhs) do
        {
          age: 30,
          profile: { middle_name: nil },
          aliases: ['A', 'B']
        }
      end
      let(:rhs) do
        {
          age: '30',
          profile: { middle_name: 'Marie' },
          aliases: ['A']
        }
      end

      it 'returns path-based differences' do
        expect(result[:is_different]).to eq(true)
        expect(result[:diff]).to match_array([
                                               { 'age' => { lhs: 30, rhs: '30', is_different: true } },
                                               { 'aliases[1]' => { lhs: 'B', rhs: nil, is_different: true } },
                                               { 'profile.middle_name' => { lhs: nil, rhs: 'Marie', is_different: true } }
                                             ])
      end
    end

    context 'when keys exist on only one side' do
      let(:lhs) { { first_name: 'Ada', legacy_id: '1234' } }
      let(:rhs) { { first_name: 'Ada', current_id: 'abcd' } }

      it 'includes each missing-key difference' do
        expect(result[:is_different]).to eq(true)
        expect(result[:diff]).to match_array([
                                               { 'legacy_id' => { lhs: '1234', rhs: nil, is_different: true } },
                                               { 'current_id' => { lhs: nil, rhs: 'abcd', is_different: true } }
                                             ])
      end
    end
  end
end
