# frozen_string_literal: true

require 'rails_helper'

shared_examples 'pagination data' do |current_offset|
  let(:query) { 'test' }
  let(:next_offset) { current_offset + 20 }
  let(:previous_offset) do
    if current_offset == 0
      nil
    else
      [current_offset - 20, 0].max
    end
  end

  subject { described_class.new(query, current_offset) }

  it 'returns the correct offsets', :aggregate_failures do
    VCR.use_cassette("search/offset_#{current_offset}") do
      response = subject.results

      next_offset = response.body['pagination']['next']
      prev_offset = response.body['pagination']['previous']

      expect(prev_offset).to eq previous_offset
      expect(next_offset).to eq next_offset
    end
  end
end
