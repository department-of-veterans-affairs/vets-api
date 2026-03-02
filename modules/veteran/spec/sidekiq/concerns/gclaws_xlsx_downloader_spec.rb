# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/sidekiq/concerns/gclaws_xlsx_downloader'

RSpec.describe GclawsXlsxDownloader do
  let(:test_class) do
    Class.new do
      include GclawsXlsxDownloader

      attr_reader :errors

      def initialize
        @errors = []
      end

      def log_error(message)
        @errors << message
      end

      # Expose private method for testing
      public :with_xlsx_file_content
    end
  end

  let(:instance) { test_class.new }
  let(:file_content) { 'binary xlsx content' }
  let(:temp_file) do
    f = Tempfile.new(['test', '.xlsx'])
    f.binmode
    f.write(file_content)
    f.close
    f
  end

  after { temp_file.unlink }

  describe '#with_xlsx_file_content' do
    context 'when download succeeds' do
      before do
        allow(RepresentationManagement::GCLAWS::XlsxClient)
          .to receive(:download_accreditation_xlsx)
          .and_yield({ success: true, file_path: temp_file.path })
      end

      it 'yields the binary file content to the block' do
        yielded = nil
        instance.with_xlsx_file_content { |content| yielded = content }
        expect(yielded).to eq(file_content)
      end
    end

    context 'when download fails' do
      before do
        allow(RepresentationManagement::GCLAWS::XlsxClient)
          .to receive(:download_accreditation_xlsx)
          .and_yield({ success: false, error: 'timeout', status: :request_timeout })
      end

      it 'does not yield to the block' do
        yielded = false
        instance.with_xlsx_file_content { yielded = true }
        expect(yielded).to be false
      end

      it 'logs the error' do
        instance.with_xlsx_file_content { |_| }
        expect(instance.errors).to include('GCLAWS download failed: timeout (status: request_timeout)')
      end
    end
  end
end
