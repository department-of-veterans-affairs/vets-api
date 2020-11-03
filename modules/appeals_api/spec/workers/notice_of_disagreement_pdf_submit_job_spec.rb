# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::NoticeOfDisagreementPdfSubmitJob, type: :job do
  subject { described_class }

  before { Sidekiq::Worker.clear_all }

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

    it 'generates the expected pdf' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      path = described_class.new.generate_pdf(notice_of_disagreement.id)
      expected_path = Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'expected_10182_extra.pdf')
      generated_pdf_md5 = Digest::MD5.digest(File.read(path))
      expected_pdf_md5 = Digest::MD5.digest(File.read(expected_path))
      File.delete(path) if File.exist?(path)
      expect(generated_pdf_md5).to eq(expected_pdf_md5)
      Timecop.return
    end
  end
end
