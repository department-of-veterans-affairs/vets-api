# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_upload_serializer'

describe VBADocuments::UploadSerializer, type: :serializer do
  subject { serialize(upload_submission, serializer_class: described_class) }

  let(:upload_submission) { build_stubbed(:upload_submission, :status_uploaded) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it_behaves_like 'VBADocuments::UploadSerializer'

  context 'when status is vbms' do
    let(:upload_submission_vbms) { build_stubbed(:upload_submission, status: 'vbms') }
    let(:response) { serialize(upload_submission_vbms, serializer_class: described_class) }
    let(:attributes_vbms) { JSON.parse(response)['data']['attributes'] }

    it 'includes :status' do
      expect(attributes_vbms['status']).to eq 'success'
    end
  end

  context 'when status is not vbms' do
    it 'includes :status' do
      expect(attributes['status']).to eq upload_submission.status
    end
  end
end
