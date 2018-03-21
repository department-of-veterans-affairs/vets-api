# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::SerializableError do
  let(:attributes) { nil }
  subject { described_class.new(attributes) }

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
end
