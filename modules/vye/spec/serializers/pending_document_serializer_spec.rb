# frozen_string_literal: true

require 'rails_helper'

describe Vye::PendingDocumentSerializer, type: :serializer do
  subject { serialize(pending_document, serializer_class: described_class) }

  let(:pending_document) { build_stubbed(:vye_pending_document) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :doc_type' do
    expect(attributes['doc_type']).to eq pending_document.doc_type
  end

  it 'includes :queue_date' do
    expect(attributes['queue_date']).to eq pending_document.queue_date.to_s
  end
end
