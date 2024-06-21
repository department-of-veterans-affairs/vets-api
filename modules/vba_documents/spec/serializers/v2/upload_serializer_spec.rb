# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_upload_serializer'

describe VBADocuments::V2::UploadSerializer, type: :serializer do
  subject { serialize(upload_submission, serializer_class: described_class) }

  before do
    allow(Settings.vba_documents).to receive(:v2_upload_endpoint_enabled).and_return(false)
  end

  let(:upload_submission) { build_stubbed(:upload_submission, status: 'vbms') }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it_behaves_like 'VBADocuments::UploadSerializer'

  it 'includes :status' do
    expect(attributes['status']).to eq upload_submission.status
  end

  context 'when observing is true' do
    before do
      allow(Webhooks::Subscription).to receive(:get_observers_by_guid).and_return([double])
    end

    let(:response) { serialize(upload_submission, serializer_class: described_class) }
    let(:attributes_location) { JSON.parse(response)['data']['attributes'] }

    it 'includes :observers' do
      expect(attributes['observers']).to be_present
    end
  end

  context 'when observing is false' do
    before do
      allow(Webhooks::Subscription).to receive(:get_observers_by_guid).and_return([])
    end

    let(:response) { serialize(upload_submission, serializer_class: described_class) }
    let(:attributes_location) { JSON.parse(response)['data']['attributes'] }

    it 'does not include :observers' do
      expect(attributes).not_to have_key('observers')
    end
  end

  context 'when v2_upload_endpoint_enabled is true' do
    before do
      allow(Settings.vba_documents).to receive(:v2_upload_endpoint_enabled).and_return(true)
    end

    let(:response) { serialize(upload_submission, serializer_class: described_class) }
    let(:attributes_location) { JSON.parse(response)['data']['attributes'] }

    it 'does not include :location' do
      expect(attributes).not_to have_key('location')
    end
  end

  context 'when v2_upload_endpoint_enabled is false' do
    before do
      allow(Settings.vba_documents).to receive(:v2_upload_endpoint_enabled).and_return(false)
    end

    let(:response) { serialize(upload_submission, serializer_class: described_class) }
    let(:attributes_location) { JSON.parse(response)['data']['attributes'] }

    it 'includes :location' do
      expect(attributes_location).to have_key('location')
    end
  end
end
