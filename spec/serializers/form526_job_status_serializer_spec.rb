# frozen_string_literal: true

require 'rails_helper'

describe Form526JobStatusSerializer, type: :serializer do
  subject { serialize(form526_job_status, serializer_class: described_class) }

  let(:form526_job_status) { create(:form526_job_status) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :type' do
    expect(data['type']).to eq 'form526_job_statuses'
  end

  it 'includes :claim_id' do
    expect(attributes['claim_id']).to eq form526_job_status.submission.submitted_claim_id
  end

  it 'includes :submission_id' do
    expect(attributes['submission_id']).to eq form526_job_status.submission.id
  end

  it 'includes :ancillary_item_statuses' do
    expected_statuses = form526_job_status.submission.form526_job_statuses.map do |status|
      status.attributes.except('form526_submission_id') unless status.id == form526_job_status.id
    end.compact

    expect(attributes['ancillary_item_statuses'].first['id']).to eq expected_statuses.first['id']
    expect(attributes['ancillary_item_statuses'].first.keys).not_to include('form526_submission_id')
  end
end
