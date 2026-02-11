# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmissionSerializer, type: :serializer do
  subject do
    serialize(evidence_submission, serializer_class: described_class, params: { render_location: })
  end

  let(:evidence_submission) { build_stubbed(:evidence_submission_v0) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:render_location) { false }

  it 'includes :id' do
    expect(data['id']).to eq evidence_submission.guid
  end

  it 'includes :appealType' do
    expect(attributes['appealType']).to eq evidence_submission.supportable_type.to_s.demodulize
  end

  it 'includes :appealId' do
    expect(attributes['appealId']).to eq evidence_submission.supportable_id
  end

  it 'includes :createDate' do
    expect_time_eq(attributes['createDate'], evidence_submission.created_at)
  end

  it 'includes :updateDate' do
    expect_time_eq(attributes['updateDate'], evidence_submission.updated_at)
  end

  context 'with a successful status on parent upload' do
    it 'includes :status' do
      expect(attributes['status']).to eq evidence_submission.status
    end

    it 'includes :code with nil value' do
      expect(attributes['code']).to be_nil
    end

    it 'includes :detail with nil value' do
      expect(attributes['detail']).to be_nil
    end
  end

  context 'when render_location is true' do
    let(:render_location) { true }
    let(:upload_submission) { evidence_submission.upload_submission }

    it 'includes location' do
      allow(upload_submission).to receive(:get_location).and_return('http://another.fakesite.com/rewrittenpath')
      location = upload_submission.get_location
      expect(attributes['location']).to eq location
    end

    it 'raises an error when get_location fails' do
      allow(upload_submission).to receive(:get_location).and_raise(StandardError, 'Test error')
      params = { params: { render_location: true } }
      expect do
        described_class.new(evidence_submission, params).serializable_hash
      end.to raise_error(Common::Exceptions::InternalServerError)
    end
  end

  context 'when render_location is false' do
    it 'does not include location' do
      expect(attributes['location']).to be_nil
    end
  end

  context "with 'error' status on parent upload" do
    let(:evidence_submission) { build_stubbed(:evidence_submission_with_error) }

    it 'includes :status' do
      expect(attributes['status']).to eq 'error'
    end

    it 'includes :code' do
      expect(attributes['code']).to eq '404'
    end

    it "truncates :detail value if longer than #{described_class::MAX_DETAIL_DISPLAY_LENGTH}" do
      max_length_plus_ellipses = described_class::MAX_DETAIL_DISPLAY_LENGTH + 3
      expect(attributes['detail'].length).to eq(max_length_plus_ellipses)
      expect(attributes['detail'][0, 100]).to include evidence_submission.detail[0, 100]
    end
  end

  context 'when :decision_review_evidence_final_status_field flag is enabled' do
    before { allow(Flipper).to receive(:enabled?).with(:decision_review_evidence_final_status_field).and_return(true) }

    it 'includes :finalStatus' do
      expect(attributes['finalStatus']).to be_in([true, false])
      expect(attributes['finalStatus']).to eq(evidence_submission.in_final_status?)
    end
  end

  context 'when :decision_review_evidence_final_status_field flag is disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:decision_review_evidence_final_status_field).and_return(false)
    end

    it 'excludes :finalStatus' do
      expect(attributes).not_to have_key('finalStatus')
    end
  end
end
