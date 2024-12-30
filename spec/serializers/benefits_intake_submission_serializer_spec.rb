# frozen_string_literal: true

require 'rails_helper'

describe BenefitsIntakeSubmissionSerializer, type: :serializer do
  subject { serialize(submission, serializer_class: described_class) }

  let(:submission) { build_stubbed(:central_mail_submission) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq submission.id.to_s
  end

  it 'includes :appointments as an array' do
    expect(attributes['state']).to eq submission.state
  end
end
