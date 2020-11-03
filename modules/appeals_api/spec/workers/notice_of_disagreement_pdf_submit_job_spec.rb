# frozen_string_literal: true

require 'rails_helper'
require 'pdf_info'

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

    # We need to revisit how we're doing content verification. At minimum we need to re-generate the expected PDF
    # in the docker container. This spec will be commented out do it's intermittent failures until a new solution
    # is implemented.
    # it 'generates the expected pdf' do
    #   Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
    #   path = described_class.new.generate_pdf(notice_of_disagreement.id)
    #   expected_path = Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'expected_10182_extra.pdf')
    #   generated_pdf_md5 = Digest::MD5.digest(File.read(path))
    #   expected_pdf_md5 = Digest::MD5.digest(File.read(expected_path))
    #   File.delete(path) if File.exist?(path)
    #   expect(generated_pdf_md5).to eq(expected_pdf_md5)
    #   Timecop.return
    # end
    #
    it 'generates the correct number of pages' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      path = described_class.new.generate_pdf(notice_of_disagreement.id)
      expect(PdfInfo::Metadata.read(path).pages).to eq(4)
      File.delete(path) if File.exist?(path)
      Timecop.return
    end
  end
end
