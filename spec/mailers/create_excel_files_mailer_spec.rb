# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateExcelFilesMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    subject do
      File.write("tmp/#{filename}", {})
      described_class.build(filename).deliver_now
    end

    let(:filename) { "22-10282_#{Time.zone.now.strftime('%m%d%Y_%H%M%S')}.csv" }
  end

  after do
    FileUtils.rm_f("tmp/#{filename}")
  end

  context 'when sending emails' do
    it 'sends the right email' do
      date = Time.zone.now.strftime('%m/%d/%Y')

      expect(subject.subject).to eq("Staging CSV file for #{date}")
      expect(subject.content_type).to eq('text/csv; charset=UTF-8')
      expect(subject.attachments.size).to eq(0)
      expect(subject.header['Content-Disposition'].to_s).to include("attachment; filename=#{filename}")
    end
  end
end
