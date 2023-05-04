# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateStagingSpoolFilesMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    subject do
      contents = File.read('spec/fixtures/education_form/stagingspool.txt')
      described_class.build(contents).deliver_now
    end

    context 'when sending emails' do
      it 'sends the right email' do
        date = Time.zone.now.strftime('%m%d%Y')

        subject_txt = "Staging Spool file on #{date}"
        body = "The staging spool file for #{date}"

        expect(subject.subject).to eq(subject_txt)
        expect(subject.body.raw_source).to include(body)
      end
    end
  end
end
