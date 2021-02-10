# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe AppealsApi::NoticeOfDisagreementPdfSubmitJob, type: :job do
  include FixtureHelpers

  subject { described_class }

  before { Sidekiq::Worker.clear_all }

  let(:auth_headers) { fixture_to_s 'valid_10182_headers.json' }
  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_doc) { fixture_to_s 'valid_10182.json' }

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
    expect(metadata['lob']).to eq(notice_of_disagreement.lob)
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
    expect(metadata['lob']).to eq(notice_of_disagreement.lob)
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

  context 'an error throws' do
    it 'updates the NOD status to reflect the error' do
      submit_job_worker = described_class.new
      allow(submit_job_worker).to receive(:upload_to_central_mail).and_raise(RuntimeError, 'runtime error!')

      begin
        submit_job_worker.perform(notice_of_disagreement.id)
      rescue
        expect(notice_of_disagreement.reload.status).to eq('error')
        expect(notice_of_disagreement.reload.code).to eq('RuntimeError')
        expect(notice_of_disagreement.reload.detail).to eq('runtime error!')
      end
    end
  end
end
