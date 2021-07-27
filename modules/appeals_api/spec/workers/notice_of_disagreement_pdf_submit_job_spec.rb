# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

RSpec.describe AppealsApi::NoticeOfDisagreementPdfSubmitJob, type: :job do
  include FixtureHelpers

  subject { described_class }

  before { Sidekiq::Worker.clear_all }

  let(:auth_headers) { fixture_to_s 'valid_10182_headers.json' }
  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_doc) { fixture_to_s 'valid_10182.json' }

  it_behaves_like 'a monitored worker'

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

    expect { described_class.new.perform(notice_of_disagreement.id) }.to raise_error(AppealsApi::UploadError)
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

    it 'puts the NOD into an error state' do
      expect(client_stub).to receive(:upload) { |_arg| faraday_response }
      allow(AppealsApi::SidekiqRetryNotifier).to receive(:notify!).and_return(true)
      described_class.new.perform(notice_of_disagreement.id)
      expect(notice_of_disagreement.reload.status).to eq('error')
      expect(notice_of_disagreement.code).to eq('DOC201')
    end

    it 'sends a retry notification' do
      expect(client_stub).to receive(:upload) { |_arg| faraday_response }
      allow(AppealsApi::SidekiqRetryNotifier).to receive(:notify!).and_return(true)
      described_class.new.perform(notice_of_disagreement.id)

      expect(AppealsApi::SidekiqRetryNotifier).to have_received(:notify!)
    end
  end

  context 'an error throws' do
    it 'updates the NOD status to reflect the error' do
      submit_job_worker = described_class.new
      allow(submit_job_worker).to receive(:upload_to_central_mail).and_raise(RuntimeError, 'runtime error!')

      expect do
        submit_job_worker.perform(notice_of_disagreement.id)
      end.to raise_error(RuntimeError, 'runtime error!')

      notice_of_disagreement.reload
      expect(notice_of_disagreement.status).to eq('error')
    end
  end
end
