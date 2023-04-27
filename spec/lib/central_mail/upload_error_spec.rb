# frozen_string_literal: true

require 'rails_helper'
require 'central_mail/upload_error'

RSpec.describe CentralMail::UploadError do
  before { expect(StatsD).to receive(:increment).with('api.central_mail.upload.fail', { tags: ["status:#{code}"] }) }

  let(:message) {}
  let(:code) {}
  let(:detail) {}
  let(:pdf_validator_options) {}
  let(:error) { described_class.new(message, code:, detail:, pdf_validator_options:) }

  describe 'default values' do
    it 'has a generic message with no code or detail' do
      expect(error).to have_attributes(code: nil, detail: nil, message: 'Internal Server Error')
    end
  end

  describe 'with custom message, detail, code' do
    let(:message) { 'banana' }
    let(:detail) { 'orange' }
    let(:code) { 'apple' }

    it 'uses the values as provided' do
      expect(error).to have_attributes(code:, detail:, message:)
    end
  end

  describe 'with recognized error code and no message' do
    let(:code) { 'DOC101' }

    it 'has a default message based on the code' do
      expect(error).to have_attributes(code:, detail:, message: 'Invalid multipart payload')
    end
  end

  describe 'DOC108' do
    let(:code) { 'DOC108' }

    it 'has a default message based on the code and the default pdf validator default settings' do
      expect(error).to have_attributes(code:, detail:, message: 'Maximum page size exceeded. Limit is 21 in x 21 in.')
    end

    context 'with custom settings' do
      let(:pdf_validator_options) { { width_limit_in_inches: 111, height_limit_in_inches: 222 } }

      it 'has a custom message based on the code and settings' do
        expect(error)
          .to have_attributes(code:, detail:, message: 'Maximum page size exceeded. Limit is 111 in x 222 in.')
      end
    end

    context 'with custom message' do
      let(:message) { 'banana' }

      it 'uses the message as provided' do
        expect(error).to have_attributes(code:, detail:, message:)
      end
    end
  end

  describe 'DOC106' do
    let(:code) { 'DOC106' }

    it 'has a default message based on the code and the default pdf validator default settings' do
      expect(error)
        .to have_attributes(code:, detail:, message: 'Maximum document size exceeded. Limit is 100 MB per document.')
    end

    context 'with custom settings' do
      let(:pdf_validator_options) { { size_limit_in_bytes: 987_654_321 } }

      it 'has a custom message based on the code and settings' do
        expect(error).to have_attributes(code:,
                                         detail:,
                                         message: 'Maximum document size exceeded. Limit is 987.654 MB per document.')
      end
    end

    context 'with custom message' do
      let(:message) { 'banana' }

      it 'uses the message as provided' do
        expect(error).to have_attributes(code:, detail:, message:)
      end
    end
  end
end
