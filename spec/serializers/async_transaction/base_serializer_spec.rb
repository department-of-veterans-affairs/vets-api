# frozen_string_literal: true

require 'rails_helper'

describe AsyncTransaction::BaseSerializer, type: :serializer do
  subject { serialize(async_transaction, serializer_class: described_class) }

  let(:async_transaction) { build_stubbed(:async_transaction) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :transaction_id' do
    expect(attributes['transaction_id']).to eq async_transaction.transaction_id
  end

  it 'includes :transaction_status' do
    expect(attributes['transaction_status']).to eq async_transaction.transaction_status
  end

  it 'includes :type' do
    expect(attributes['type']).to eq async_transaction.type
  end

  it 'includes :metadata' do
    expect(attributes['metadata']).to eq async_transaction.parsed_metadata
  end
end
