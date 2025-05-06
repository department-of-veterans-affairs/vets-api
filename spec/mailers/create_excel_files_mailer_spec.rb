# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateExcelFilesMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    timestamp = Time.zone.now.strftime('%m%d%Y_%H%M%S')
    filename = "22-10282_#{timestamp}.csv"

    subject do
      File.write("tmp/#{filename}", {})
      described_class.build(filename).deliver_now
    end

    after do
      FileUtils.rm_f("tmp/#{filename}")
    end

    context 'when sending emails' do
      it 'sends the right email' do
        date = Time.zone.now.strftime('%m/%d/%Y')
        expect(subject.subject).to eq("(Staging) 22-10282 CSV file for #{date}")
        expect(subject.content_type).to include('multipart/mixed')
        expect(subject.content_type).to include('charset=UTF-8')
        expect(subject.attachments.size).to eq(1)
      end
    end
  end
end
