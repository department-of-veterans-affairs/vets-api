# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateStagingExcelFilesMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    subject do
      allow(File).to receive(:read).with("tmp/#{filename}").and_return(file_contents)
      described_class.build(filename).deliver_now
    end

    let(:filename) { 'test_data.csv' }
    let(:file_contents) { "header1,header2\nvalue1,value2" }

    context 'when sending emails' do
      it 'sends the right email' do
        date = Time.zone.now.strftime('%m/%d/%Y')

        expect(subject.subject).to eq("Staging CSV file for #{date}")
        expect(subject.body.raw_source).to eq(file_contents)
        expect(subject.content_type).to include('text/csv')
        expect(subject.headers['Content-Disposition']).to eq("attachment; filename=#{filename}")
      end
    end
  end
end
