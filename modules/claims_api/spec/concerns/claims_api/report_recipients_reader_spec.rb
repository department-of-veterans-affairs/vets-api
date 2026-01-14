# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::ReportRecipientsReader do
  let(:test_class) { Class.new { include ClaimsApi::ReportRecipientsReader } }
  let(:report) { test_class.new }

  describe '#load_recipients' do
    let(:recipient_file_path) { ClaimsApi::Engine.root.join('config', 'mailinglists', 'mailinglist.yml') }

    context 'when the file exists and has valid data' do
      let(:mock_yaml_data) do
        {
          'common' => ['user1@example.com', 'user2@example.com'],
          'submission_report_mailer' => ['submission1@example.com'],
          'unsuccessful_report_mailer' => ['unsuccessful1@example.com'],
          'empty' => []
        }
      end

      before do
        allow(File).to receive(:exist?).with(recipient_file_path).and_return(true)
        allow(YAML).to receive(:safe_load_file).with(recipient_file_path).and_return(mock_yaml_data)
      end

      it 'loads common recipients plus specific recipient type' do
        recipients = report.load_recipients('submission_report_mailer')
        expect(recipients).to contain_exactly('user1@example.com', 'user2@example.com', 'submission1@example.com')
      end

      it 'loads only common recipients when recipient type has no specific entries' do
        recipients = report.load_recipients('empty')
        expect(recipients).to contain_exactly('user1@example.com', 'user2@example.com')
      end

      it 'returns common recipients when recipient type does not exist in file' do
        recipients = report.load_recipients('nonexistent_type')
        expect(recipients).to eq(['user1@example.com', 'user2@example.com'])
      end
    end

    context 'when the file exists but is empty' do
      before do
        allow(File).to receive(:exist?).with(recipient_file_path).and_return(true)
        allow(YAML).to receive(:safe_load_file).with(recipient_file_path).and_return(nil)
      end

      it 'returns an empty array and logs a warning' do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'ReportRecipientsReader',
          { message: "Recipients file is empty or invalid: #{recipient_file_path}", level: :warn }
        )
        expect(report.load_recipients('submission_report_mailer')).to eq([])
      end
    end

    context 'when the file does not exist' do
      before do
        allow(File).to receive(:exist?).with(recipient_file_path).and_return(false)
      end

      it 'returns an empty array and logs a warning' do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'ReportRecipientsReader',
          { message: "Recipients file does not exist: #{recipient_file_path}", level: :warn }
        )
        expect(report.load_recipients('submission_report_mailer')).to eq([])
      end
    end

    context 'when YAML parsing fails' do
      before do
        allow(File).to receive(:exist?).with(recipient_file_path).and_return(true)
        allow(YAML).to receive(:safe_load_file)
          .with(recipient_file_path)
          .and_raise(Psych::SyntaxError.new('file', 1, 1, 0, 'syntax error', 'context'))
      end

      it 'returns an empty array and logs the error' do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'ReportRecipientsReader',
          hash_including(message: /Failed to load recipients from #{recipient_file_path}:.*syntax error/, level: :warn)
        )
        expect(report.load_recipients('submission_report_mailer')).to eq([])
      end
    end

    context 'when YAML returns non-hash data' do
      before do
        allow(File).to receive(:exist?).with(recipient_file_path).and_return(true)
        allow(YAML).to receive(:safe_load_file).with(recipient_file_path).and_return('invalid data')
      end

      it 'returns an empty array and logs a warning' do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'ReportRecipientsReader',
          { message: "Recipients file is empty or invalid: #{recipient_file_path}", level: :warn }
        )
        expect(report.load_recipients('submission_report_mailer')).to eq([])
      end
    end

    context 'with actual mailinglist.yml file' do
      it 'loads recipients from the real file' do
        if File.exist?(recipient_file_path)
          recipients = report.load_recipients('submission_report_mailer')
          expect(recipients).to be_an(Array)
          expect(recipients).not_to be_empty
          expect(recipients.first).to match(/@/)
        else
          skip 'mailinglist.yml file does not exist'
        end
      end
    end
  end
end
