# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::SerializableError do
  subject { described_class.new(attributes) }

  let(:attributes) { nil }

  context 'with no attributes' do
    it 'responds to #to_hash' do
      expect(subject.to_hash).to eq({})
    end
  end

  context 'with arbitrary attributes' do
    let(:attributes) { { cat: 1, dog: 2 } }

    it 'responds to #to_hash' do
      expect(subject.to_hash).to eq({})
    end
  end

  context 'with some blank attribute' do
    let(:attributes) { { title: 'title', detail: ' ', source: [] } }

    it 'to_hash removes non-present values' do
      expect(subject.to_hash).to eq({ title: 'title' })
    end
  end

  context 'with actual attributes' do
    let(:attributes) do
      {
        title: 'title', detail: 'detail', id: 123, href: 'href', code: '123',
        source: 'source', status: '500', meta: 'meta'
      }
    end

    it 'responds to #to_hash' do
      expect(subject.to_hash).to eq(attributes)
    end
  end

  context 'with source as a hash' do
    let(:attributes) do
      {
        title: 'title', detail: 'detail', code: '123',
        source: { vamf_url: 'https://example.com', vamf_body: 'error body', vamf_status: 500 },
        status: '500'
      }
    end

    it 'responds to #to_hash with hash source' do
      expect(subject.to_hash).to eq(attributes)
    end
  end
end
