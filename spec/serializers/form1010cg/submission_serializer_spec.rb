# frozen_string_literal: true

require 'rails_helper'

describe Form1010cg::SubmissionSerializer do
  subject { serialize(submission, serializer_class: described_class) }

  let(:submission) { build(:form1010cg_submission, :with_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :confirmation_number' do
    expect(attributes['confirmation_number']).to eq submission.carma_case_id
  end

  it 'includes :submitted_at' do
    expect_time_eq(attributes['submitted_at'], submission.accepted_at)
  end
end
