# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::PendingDocumentSerializer, type: :serializer do
  subject { described_class.new(pending_document).to_json }

  let(:pending_document) { build_stubbed(:vye_pending_document) }
  let(:data) { JSON.parse(subject) }

  it 'includes :doc_type' do
    expect(data['doc_type']).to eq pending_document.doc_type
  end

  it 'includes :queue_date' do
    expect(data['queue_date']).to eq pending_document.queue_date.to_s
  end
end
