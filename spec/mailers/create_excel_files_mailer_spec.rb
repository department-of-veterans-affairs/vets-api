# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateExcelFilesMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    subject do
      File.write("tmp/#{filename}", csv_contents)
      described_class.build(filename).deliver_now
    end

    let(:filename) { "22-10282_#{Time.zone.now.strftime('%m%d%Y_%H%M%S')}.csv" }
    let(:csv_contents) do
      CSV.generate(row_sep: "\r\n") do |csv|
        csv << ['Name', 'First Name', 'Last Name', 'Select Military Affiliation',
                'Phone Number', 'Email Address', 'Country', 'State', 'Race/Ethnicity',
                'Gender of Applicant', 'What is your highest level of education?',
                'Are you currently employed?', 'What is your current salary?',
                'Are you currently working in the technology industry? (If so, please select one)']
        csv << ['Mark Olson', 'Mark', 'Olson', 'veteran', '1234567890', 'test@sample.com', 'United States', 'FL',
                '{"isBlackOrAfricanAmerican"=>true}', 'M', 'MD', 'true', 'moreThanSeventyFive', 'CP']
      end
    end

    after do
      FileUtils.rm_f("tmp/#{filename}")
    end

    context 'when sending emails' do
      it 'sends the right email' do
        date = Time.zone.now.strftime('%m/%d/%Y')

        expect(subject.subject).to eq("Staging CSV file for #{date}")
        expect(subject.content_type).to eq('text/csv; charset=UTF-8')
        expect(subject.body.raw_source).to eq(csv_contents)
        expect(subject.attachments.size).to eq(0)
        expect(subject.header['Content-Disposition'].to_s).to include("attachment; filename=#{filename}")
      end
    end
  end
end
