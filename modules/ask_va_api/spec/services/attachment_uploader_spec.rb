# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AttachmentUploader do
  let(:small_file) { double('File', size: 10.megabytes, content_type: 'application/pdf') }
  let(:large_file) { double('File', size: 30.megabytes, content_type: 'application/pdf') }
  let(:no_file) { nil }

  describe '#call' do
    context 'when no file is attached' do
      subject { described_class.new(no_file).call }

      it 'returns a bad request status' do
        expect(subject[:status]).to eq(:bad_request)
        expect(subject[:error]).to eq('No file attached')
      end
    end

    context 'when the file size exceeds the limit' do
      subject { described_class.new(large_file).call }

      it 'returns an unprocessable entity status' do
        expect(subject[:status]).to eq(:unprocessable_entity)
        expect(subject[:error]).to eq('File size exceeds the allowed limit')
      end
    end

    context 'when the file size is within the limit' do
      subject { described_class.new(small_file).call }

      it 'returns an ok status' do
        expect(subject[:status]).to eq(:ok)
        expect(subject[:message]).to eq('Attachment has been received')
      end
    end
  end
end
