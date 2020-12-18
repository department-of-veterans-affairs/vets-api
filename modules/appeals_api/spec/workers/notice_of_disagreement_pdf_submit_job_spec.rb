# frozen_string_literal: true

require 'rails_helper'
require 'pdf_info'

RSpec.describe AppealsApi::NoticeOfDisagreementPdfSubmitJob, type: :job do
  subject { described_class }

  before { Sidekiq::Worker.clear_all }

  let(:auth_headers) do
    File.read(
      Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'valid_10182_headers.json')
    )
  end

  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_doc) { File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'valid_10182.json')) }

  it 'uploads a valid payload' do
    allow(CentralMail::Service).to receive(:new) { client_stub }
    allow(faraday_response).to receive(:status).and_return(200)
    allow(faraday_response).to receive(:body).and_return('')
    allow(faraday_response).to receive(:success?).and_return(true)
    capture_body = nil
    expect(client_stub).to receive(:upload) { |arg|
      capture_body = arg
      faraday_response
    }
    described_class.new.perform(notice_of_disagreement.id)
    expect(capture_body).to be_a(Hash)
    expect(capture_body).to have_key('metadata')
    expect(capture_body).to have_key('document')
    metadata = JSON.parse(capture_body['metadata'])
    expect(metadata['uuid']).to eq(notice_of_disagreement.id)
    updated = AppealsApi::NoticeOfDisagreement.find(notice_of_disagreement.id)
    expect(updated.status).to eq('submitted')
  end

  it 'sets error status for upstream server error' do
    allow(CentralMail::Service).to receive(:new) { client_stub }
    allow(faraday_response).to receive(:status).and_return(422)
    allow(faraday_response).to receive(:body).and_return('')
    allow(faraday_response).to receive(:success?).and_return(false)
    capture_body = nil
    expect(client_stub).to receive(:upload) { |arg|
      capture_body = arg
      faraday_response
    }
    described_class.new.perform(notice_of_disagreement.id)
    expect(capture_body).to be_a(Hash)
    expect(capture_body).to have_key('metadata')
    expect(capture_body).to have_key('document')
    metadata = JSON.parse(capture_body['metadata'])
    expect(metadata['uuid']).to eq(notice_of_disagreement.id)
    updated = AppealsApi::NoticeOfDisagreement.find(notice_of_disagreement.id)
    expect(updated.status).to eq('error')
    expect(updated.code).to eq('DOC104')
  end

  context 'with a downstream error' do
    before do
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(500)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(false)
    end

    it 'queues another job to retry the request' do
      expect(client_stub).to receive(:upload) { |_arg| faraday_response }
      Timecop.freeze(Time.zone.now)
      described_class.new.perform(notice_of_disagreement.id)
      expect(described_class.jobs.last['at']).to eq(30.minutes.from_now.to_f)
      Timecop.return
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
    let(:rep_name) { notice_of_disagreement.form_data.dig 'data', 'attributes', 'veteran', 'representativesName' }
    let(:extra_issue) { notice_of_disagreement.form_data['included'].last.dig('attributes', 'issue') }

    it 'generates pdf with expected content' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      generated_pdf = described_class.new.generate_pdf(notice_of_disagreement.id)
      reader = PDF::Reader.new(generated_pdf)
      expect(reader.pages.size).to eq 5
      expect(reader.pages.first.text).to include rep_name
      expect(reader.pages[3].text).to include 'Hearing type requested: Central office'
      expect(reader.pages[4].text).to include extra_issue
      File.delete(generated_pdf) if File.exist?(generated_pdf)
      Timecop.return
    end
  end
end
