# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_examples_upload_serializer'

describe VBADocuments::V2::UploadSerializer, skip: 'v2 will never be launched in vets-api', type: :serializer do
  subject { serialize(upload_submission, serializer_class: described_class) }

  before do
    allow(Settings.vba_documents).to receive(:v2_upload_endpoint_enabled).and_return(false)
  end

  let(:upload_submission) { build_stubbed(:upload_submission, :status_uploaded) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it_behaves_like 'VBADocuments::UploadSerializer'

  context 'when observing is true' do
    before do
      allow(Webhooks::Subscription).to receive(:get_observers_by_guid).and_return([double])
    end

    it 'includes :observers' do
      expect(attributes).to have_key('observers')
    end
  end

  context 'when observing is false' do
    before do
      allow(Webhooks::Subscription).to receive(:get_observers_by_guid).and_return([])
    end

    it 'does not include :observers' do
      expect(attributes).not_to have_key('observers')
    end
  end
end
