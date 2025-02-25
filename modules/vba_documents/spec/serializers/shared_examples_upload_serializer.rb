# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'VBADocuments::UploadSerializer' do
  it 'includes :id' do
    expect(data['id']).to eq upload_submission.guid.to_s
  end

  it 'includes :type' do
    expect(data['type']).to eq 'document_upload'
  end

  it 'includes :guid' do
    expect(attributes['guid']).to eq upload_submission.guid
  end

  it 'includes :status' do
    expect(attributes['status']).to eq upload_submission.status
  end

  it 'includes :code' do
    expect(attributes['code']).to eq upload_submission.code
  end

  context 'when detail length is > 200' do
    let(:upload_submission_with_detail) { build_stubbed(:upload_submission_large_detail) }
    let(:response) { serialize(upload_submission_with_detail, serializer_class: described_class) }
    let(:attributes_long_detail) { JSON.parse(response)['data']['attributes'] }

    it 'includes :detail and truncates' do
      max_length = VBADocuments::UploadSerializer::MAX_DETAIL_DISPLAY_LENGTH
      truncated_detail = "#{upload_submission_with_detail.detail[0..max_length - 1]}..."
      expect(attributes_long_detail['detail']).to eq truncated_detail
    end
  end

  context 'when detail length is <= 200' do
    let(:upload_submission_with_detail) { build_stubbed(:upload_submission, :status_error) }
    let(:response) { serialize(upload_submission_with_detail, serializer_class: described_class) }
    let(:attributes_short_detail) { JSON.parse(response)['data']['attributes'] }

    it 'includes :detail without truncating' do
      expect(attributes_short_detail['detail']).to eq upload_submission_with_detail.detail
    end
  end

  context 'when detail is nil' do
    it 'includes :detail as empty string' do
      expect(attributes['detail']).to eq ''
    end
  end

  it 'includes :final_status' do
    expect(attributes['final_status']).to be_in([true, false])
    expect(attributes['final_status']).to eq(upload_submission.in_final_status?)
  end

  it 'includes :updated_at' do
    expect_time_eq(attributes['updated_at'], upload_submission.updated_at)
  end

  context 'when render_location is true' do
    before do
      allow(upload_submission).to receive(:get_location).and_return('http://another.fakesite.com/rewrittenpath')
    end

    let(:response) do
      serialize(upload_submission, { serializer_class: described_class, params: { render_location: true } })
    end
    let(:attributes_location) { JSON.parse(response)['data']['attributes'] }

    it 'includes :location' do
      expect(attributes_location['location']).to eq upload_submission.get_location
    end
  end

  context 'when render_location is false or nil' do
    it 'excludes :location' do
      expect(attributes).not_to have_key('location')
    end
  end

  context 'when get_location raises an error' do
    before do
      allow(upload_submission).to receive(:get_location).and_raise(StandardError, 'test error')
    end

    it 'raises an internal server error' do
      expect { serialize(upload_submission, { serializer_class: described_class, params: { render_location: true } }) }
        .to raise_error(Common::Exceptions::InternalServerError, 'Internal server error')
    end
  end

  it 'includes :uploaded_pdf' do
    expect(attributes['uploaded_pdf']).to eq upload_submission.uploaded_pdf
  end
end
