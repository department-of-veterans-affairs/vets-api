# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_upload_serializer'

describe VBADocuments::V1::UploadSerializer, type: :serializer do
  subject { serialize(upload_submission, serializer_class: described_class) }

  let(:upload_submission) { build_stubbed(:upload_submission, status: 'vbms') }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it_behaves_like 'VBADocuments::UploadSerializer'

  it 'includes :status' do
    expect(attributes['status']).to eq upload_submission.status
  end
end
