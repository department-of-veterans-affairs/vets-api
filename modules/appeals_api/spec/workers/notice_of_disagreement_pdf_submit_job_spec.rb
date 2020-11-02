# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::NoticeOfDisagreementPdfSubmitJob, type: :job do
  subject { described_class }

  before { Sidekiq::Worker.clear_all }

  let(:auth_headers) do
    File.read(
      Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'valid_10182_headers.json')
    )
  end

  let(:notice_of_disagreement) { create_notice_of_disagreement(:notice_of_disagreement) }

  context 'pdf extra content verification' do
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

  private

  def create_notice_of_disagreement(type)
    notice_of_disagreement = create(type)
    notice_of_disagreement.auth_headers = JSON.parse(auth_headers)
    notice_of_disagreement.save
    notice_of_disagreement
  end
end
