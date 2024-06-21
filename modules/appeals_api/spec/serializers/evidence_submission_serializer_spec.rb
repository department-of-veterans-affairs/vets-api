# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::EvidenceSubmissionSerializer do
  let(:evidence_submission) { build_stubbed(:evidence_submission) }
  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(evidence_submission, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  context 'when initialized with an object that cannot be called by the delegated attributes' do
    it 'raises an error' do
      expect { described_class.new(nil).serializable_hash }.to raise_error(NoMethodError)
    end
  end

  it 'includes guid' do
    expect(rendered_hash[:data][:id]).to eq evidence_submission.guid
  end

  it 'includes :appeal_type' do
    expect(rendered_attributes[:appeal_type]).to eq 'NoticeOfDisagreement'
  end

  it 'includes :appeal_id' do
    expect(rendered_attributes[:appeal_id]).to eq evidence_submission.supportable.id
  end

  it 'includes :created_at' do
    expect(rendered_attributes[:created_at].to_s).to eq evidence_submission.created_at.to_s
  end

  it 'includes :updated_at' do
    expect(rendered_attributes[:updated_at].to_s).to eq evidence_submission.updated_at.to_s
  end

  context 'with a successful status on parent upload' do
    it 'includes :status' do
      expect(rendered_attributes[:status]).to eq evidence_submission.status
    end

    it 'includes :code with nil value' do
      expect(rendered_attributes[:code]).to be nil
    end

    it 'includes :detail with nil value' do
      expect(rendered_attributes[:detail]).to be nil
    end
  end

  context 'when render_location is true' do
    let(:upload_submission) { evidence_submission.upload_submission }

    it 'includes location' do
      allow(upload_submission).to receive(:get_location).and_return('http://another.fakesite.com/rewrittenpath')
      options = { serializer: described_class, render_location: true }
      rendered_with_location_hash = ActiveModelSerializers::SerializableResource.new(evidence_submission,
                                                                                     options).as_json
      location = upload_submission.get_location
      expect(rendered_with_location_hash[:data][:attributes][:location]).to eq location
    end

    it 'raises an error when get_location fails' do
      allow(upload_submission).to receive(:get_location).and_raise(StandardError, 'Test error')

      expect do
        described_class.new(evidence_submission, { render_location: true }).serializable_hash
      end.to raise_error(Common::Exceptions::InternalServerError)
    end
  end

  context 'when render_location is false' do
    it 'includes location' do
      expect(rendered_hash[:location]).to be nil
    end
  end

  context "with 'error' status on parent upload" do
    let(:submission_with_error) { build_stubbed(:evidence_submission_with_error) }
    let(:rendered_error_hash) { ActiveModelSerializers::SerializableResource.new(submission_with_error).as_json }

    it 'includes :status' do
      expect(rendered_error_hash[:data][:attributes][:status]).to eq 'error'
    end

    it 'includes :code' do
      expect(rendered_error_hash[:data][:attributes][:code]).to eq '404'
    end

    it "truncates :detail value if longer than #{described_class::MAX_DETAIL_DISPLAY_LENGTH}" do
      max_length_plus_ellipses = described_class::MAX_DETAIL_DISPLAY_LENGTH + 3
      expect(rendered_error_hash[:data][:attributes][:detail].length).to eq(max_length_plus_ellipses)
      expect(rendered_error_hash[:data][:attributes][:detail][0, 100]).to include submission_with_error.detail[0, 100]
    end
  end
end
