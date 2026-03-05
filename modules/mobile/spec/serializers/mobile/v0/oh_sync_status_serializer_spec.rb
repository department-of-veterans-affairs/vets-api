# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::OhSyncStatusSerializer, type: :serializer do
  subject { described_class.new(id, sync_status_data) }

  let(:id) { 'some-user-uuid' }
  let(:sync_status_data) { { status: 'complete', sync_complete: true, error: nil } }
  let(:serialized) { subject.serializable_hash }
  let(:data) { serialized[:data] }
  let(:attributes) { data[:attributes] }

  it 'includes the correct type' do
    expect(data[:type]).to eq(:oh_sync_status)
  end

  it 'includes :id' do
    expect(data[:id]).to eq(id)
  end

  it 'includes :status' do
    expect(attributes[:status]).to eq('complete')
  end

  it 'includes :sync_complete' do
    expect(attributes[:sync_complete]).to be(true)
  end

  it 'includes :error' do
    expect(attributes[:error]).to be_nil
  end

  context 'when sync has an error' do
    let(:sync_status_data) { { status: 'error', sync_complete: false, error: 'something went wrong' } }

    it 'includes the error message' do
      expect(attributes[:error]).to eq('something went wrong')
    end

    it 'includes sync_complete as false' do
      expect(attributes[:sync_complete]).to be(false)
    end

    it 'includes status as error' do
      expect(attributes[:status]).to eq('error')
    end
  end
end
