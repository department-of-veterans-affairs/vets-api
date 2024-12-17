# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_examples_upload_serializer'

describe VBADocuments::UploadSerializer, type: :serializer do
  subject { serialize(upload_submission, serializer_class: described_class) }

  let(:upload_submission) { build_stubbed(:upload_submission, :status_uploaded) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it_behaves_like 'VBADocuments::UploadSerializer'
end
