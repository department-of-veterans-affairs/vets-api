# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010EzrAttachments::FileTypeValidator do
  let(:attachment) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('spec', 'fixtures', 'files', 'empty_file.txt'),
      'empty_file.txt'
    )
  end

  describe '#validate' do
    context 'when an exception occurs' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'increments StatsD and logs and raises an error' do
        error_message = "undefined method `tempfile' for an instance of String"

        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('api.1010ezr.attachments.failed')

        expect { described_class.new('test').validate }.to raise_error do |e|
          expect(e).to be_a(NoMethodError)
          expect(e.message).to eq(error_message)
        end

        expect(Rails.logger).to have_received(:error).with(
          "Form1010EzrAttachment validate file type failed #{error_message}.",
          backtrace: anything
        )
      end
    end

    context 'when no exception occurs' do
      it 'increments StatsD and raises an error' do
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('api.1010ezr.attachments.invalid_file_type')

        expect { described_class.new(attachment).validate }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::UnprocessableEntity)
          expect(e.errors.first.status).to eq('422')
          expect(e.errors.first.detail).to eq(
            'File type not supported. Follow the instructions on your device ' \
            'on how to convert the file type and try again to continue.'
          )
        end
      end
    end
  end
end
