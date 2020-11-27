# frozen_string_literal: true

require 'rails_helper'
require 'pdf_info'

RSpec.describe AppealsApi::NoticeOfDisagreementPdfSubmitJob, type: :job do
  subject { described_class }

  before { Sidekiq::Worker.clear_all }

  # This is a temporary spec until addition of uploading to central mail is implemented.
  # Test coverage fell beneath 90% due to `#perform` not being tested. Once central mail upload
  # is implemented another spec will replace this one testing `#perform`
  describe '#perform' do
    let(:notice_of_disagreement) { create(:minimal_notice_of_disagreement) }

    it 'calls generate_pdf' do
      submit_job = described_class.new
      expect(submit_job).to receive(:generate_pdf).and_call_original.once
      submit_job.perform(notice_of_disagreement.id)
    end
  end

  context 'pdf minimum content verification' do
    let(:notice_of_disagreement) { create(:minimal_notice_of_disagreement) }

    it 'generates the expected pdf' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      path = described_class.new.generate_pdf(notice_of_disagreement.id)
      expected_path = Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'expected_10182_minimum.pdf')
      generated_pdf_md5 = Digest::MD5.digest(File.read(path))
      expected_pdf_md5 = Digest::MD5.digest(File.read(expected_path))
      File.delete(path) if File.exist?(path)
      expect(generated_pdf_md5).to eq(expected_pdf_md5)
      Timecop.return
    end
  end

  context 'pdf extra content verification' do
    let(:notice_of_disagreement) { create(:notice_of_disagreement) }
    let(:email) { notice_of_disagreement.form_data.dig 'data', 'attributes', 'veteran', 'emailAddressText' }
    let(:rep_name) { notice_of_disagreement.form_data.dig 'data', 'attributes', 'veteran', 'representativesName' }
    let(:extra_issue) { notice_of_disagreement.form_data['included'].last.dig('attributes', 'issue') }

    it 'generates pdf with expected content' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      generated_pdf = described_class.new.generate_pdf(notice_of_disagreement.id)
      reader = PDF::Reader.new(generated_pdf)
      expect(reader.pages.size).to eq 4
      expect(reader.pages.first.text).to include email
      expect(reader.pages.first.text).to include rep_name
      expect(reader.pages[3].text).to include extra_issue
      File.delete(generated_pdf) if File.exist?(generated_pdf)
      Timecop.return
    end
  end
end
