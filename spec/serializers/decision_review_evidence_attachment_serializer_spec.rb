# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DecisionReviewEvidenceAttachmentSerializer, type: :serializer do
  subject { serialize(attachment, serializer_class: described_class) }

  let(:attachment) { build_stubbed(:decision_review_evidence_attachment) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id'].to_i).to eq attachment.id
  end

  it 'includes :guid' do
    expect(attributes['guid']).to eq attachment.guid
  end
end
