# frozen_string_literal: true

require 'rails_helper'

describe SupportingEvidenceAttachmentSerializer, type: :serializer do
  subject { serialize(attachment, serializer_class: described_class) }

  let(:attachment) { build_stubbed(:supporting_evidence_attachment, :with_file_data) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq attachment.id.to_s
  end

  it 'includes :guid' do
    expect(attributes['guid']).to eq attachment.guid
  end
end
