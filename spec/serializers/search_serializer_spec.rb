# frozen_string_literal: true

require 'rails_helper'
require 'search/response'

describe SearchSerializer, type: :serializer do
  subject { serialize(search_response, serializer_class: described_class) }

  let(:search_attributes) { { body: { query: 'benefits' } } }
  let(:search_response) do
    pagination = { current_page: 1, per_page: 10, total_pages: 9, total_entries: 85 }
    Search::ResultsResponse.new(200, pagination, search_attributes)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :body' do
    expect(attributes['body']).to eq search_attributes[:body].deep_stringify_keys
  end
end
