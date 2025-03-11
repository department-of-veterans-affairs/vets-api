# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

require 'appeals_api/hlr_pdf_submit_wrapper'
require 'appeals_api/nod_pdf_submit_wrapper'
require 'appeals_api/sc_pdf_submit_wrapper'

RSpec.describe AppealsApi::PdfSubmitJob, type: :job do
  include FixtureHelpers

  subject { described_class }

  before { Sidekiq::Job.clear_all }

  let(:higher_level_review) { create(:higher_level_review_v2) }
  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:supplemental_claim) { create(:supplemental_claim) }
  let(:client_stub) { instance_double(CentralMail::Service) }
  let(:faraday_response) { instance_double(Faraday::Response) }

  after do
    client_stub { nil }
    faraday_response { nil }
  end

  it_behaves_like 'a monitored worker'

  describe 'uploads a valid payload' do
    it 'HLRv2' do
      Timecop.freeze(DateTime.new(2020, 1, 1).utc) do
        file_digest_stub = instance_double(Digest::SHA256)
        allow(Digest::SHA256).to receive(:file) { file_digest_stub }
        allow(file_digest_stub).to receive(:hexdigest).and_return('file_digest_12345')

        allow(CentralMail::Service).to receive(:new) { client_stub }
        allow(faraday_response).to receive_messages(status: 200, body: '', success?: true)
        capture_body = nil
        expect(client_stub).to receive(:upload) { |arg|
          capture_body = arg
          faraday_response
        }
        described_class.new.perform(higher_level_review.id, 'AppealsApi::HigherLevelReview', 'V2')
        metadata = JSON.parse(capture_body['metadata'])

        expect(capture_body).to be_a(Hash)
        expect(capture_body).to have_key('metadata')
        expect(metadata).to eq({
                                 'veteranFirstName' => 'Jane',
                                 'veteranLastName' => 'Doe',
                                 'fileNumber' => '987654321',
                                 'zipCode' => '66002',
                                 'source' => 'Appeals-HLR-va.gov',
                                 'uuid' => higher_level_review.id,
                                 'hashV' => 'file_digest_12345',
                                 'numberAttachments' => 0,
                                 'receiveDt' => '2019-12-31 18:00:00',
                                 'numberPages' => 3,
                                 'businessLine' => 'FID',
                                 'docType' => '20-0996'
                               })
        expect(capture_body).to have_key('document')
        expect(capture_body['document'].original_filename).to eq('200996-document.pdf')
        expect(capture_body['document'].content_type).to eq('application/pdf')

        updated = AppealsApi::HigherLevelReview.find(higher_level_review.id)
        expect(updated.status).to eq('submitted')
      end
    end

    it 'NOD' do
      Timecop.freeze(DateTime.new(2020, 1, 1).utc) do
        allow(CentralMail::Service).to receive(:new) { client_stub }
        file_digest_stub = instance_double(Digest::SHA256)
        allow(Digest::SHA256).to receive(:file) { file_digest_stub }
        allow(file_digest_stub).to receive(:hexdigest).and_return('file_digest_12345')

        allow(faraday_response).to receive_messages(status: 200, body: '', success?: true)
        capture_body = nil
        expect(client_stub).to receive(:upload) { |arg|
          capture_body = arg
          faraday_response
        }
        described_class.new.perform(notice_of_disagreement.id, 'AppealsApi::NoticeOfDisagreement')
        expect(capture_body).to be_a(Hash)
        expect(capture_body).to have_key('metadata')
        expect(capture_body).to have_key('document')
        metadata = JSON.parse(capture_body['metadata'])
        expect(metadata).to eq({
                                 'veteranFirstName' => 'Jane',
                                 'veteranLastName' => 'Doe',
                                 'fileNumber' => '987654321',
                                 'zipCode' => '00000',
                                 'source' => 'Appeals-NOD-va.gov',
                                 'uuid' => notice_of_disagreement.id,
                                 'hashV' => 'file_digest_12345',
                                 'numberAttachments' => 0,
                                 'receiveDt' => '2019-12-31 18:00:00',
                                 'numberPages' => 4,
                                 'docType' => '10182',
                                 'businessLine' => 'BVA'
                               })
        expect(metadata['uuid']).to eq(notice_of_disagreement.id)
        expect(metadata['businessLine']).to eq(notice_of_disagreement.lob)

        expect(capture_body['document'].original_filename).to eq('10182-document.pdf')
        expect(capture_body['document'].content_type).to eq('application/pdf')

        updated = AppealsApi::NoticeOfDisagreement.find(notice_of_disagreement.id)
        expect(updated.status).to eq('submitted')
      end
    end

    it 'SC' do
      Timecop.freeze(DateTime.new(2020, 1, 1).utc) do
        file_digest_stub = instance_double(Digest::SHA256)
        allow(Digest::SHA256).to receive(:file) { file_digest_stub }
        allow(file_digest_stub).to receive(:hexdigest).and_return('file_digest_12345')

        allow(CentralMail::Service).to receive(:new) { client_stub }
        allow(faraday_response).to receive_messages(status: 200, body: '', success?: true)
        capture_body = nil
        expect(client_stub).to receive(:upload) { |arg|
          capture_body = arg
          faraday_response
        }
        described_class.new.perform(supplemental_claim.id, 'AppealsApi::SupplementalClaim', 'V2')
        metadata = JSON.parse(capture_body['metadata'])

        expect(capture_body).to be_a(Hash)
        expect(capture_body).to have_key('metadata')
        expect(metadata).to eq({
                                 'veteranFirstName' => 'Jane',
                                 'veteranLastName' => 'Doe',
                                 'fileNumber' => '987654321',
                                 'zipCode' => '30012',
                                 'source' => 'Appeals-SC-va.gov',
                                 'uuid' => supplemental_claim.id,
                                 'hashV' => 'file_digest_12345',
                                 'numberAttachments' => 0,
                                 'receiveDt' => '2019-12-31 18:00:00',
                                 'numberPages' => 2,
                                 'businessLine' => 'FID',
                                 'docType' => '20-0995'
                               })
        expect(capture_body).to have_key('document')
        expect(capture_body['document'].original_filename).to eq('200995-document.pdf')
        expect(capture_body['document'].content_type).to eq('application/pdf')

        updated = AppealsApi::SupplementalClaim.find(supplemental_claim.id)
        expect(updated.status).to eq('submitted')
      end
    end
  end

  it 'sets error status for upstream server error' do
    allow(CentralMail::Service).to receive(:new) { client_stub }
    allow(faraday_response).to receive_messages(status: 500, body: 'Server Down', success?: false)
    capture_body = nil
    expect(client_stub).to receive(:upload) { |arg|
      capture_body = arg
      faraday_response
    }

    expect { described_class.new.perform(notice_of_disagreement.id, 'AppealsApi::NoticeOfDisagreement') }
      .to(raise_error do |ue|
        expect(ue).to be_a(AppealsApi::UploadError)
        expect(ue.code).to eq 'DOC201'
        expect(ue.upstream_http_resp_status).to eq 500
        expect(ue.detail).to eq 'Downstream status: 500 - Server Down'
      end)

    expect(capture_body).to be_a(Hash)
    expect(capture_body).to have_key('metadata')
    expect(capture_body).to have_key('document')
    metadata = JSON.parse(capture_body['metadata'])
    expect(metadata['uuid']).to eq(notice_of_disagreement.id)
    updated = AppealsApi::NoticeOfDisagreement.find(notice_of_disagreement.id)
    expect(updated.status).to eq('error')
    expect(updated.code).to eq('DOC201')
  end

  context 'with a downstream error' do
    before do
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive_messages(status: 501, body: '', success?: false)
    end

    it 'puts the NOD into an error state' do
      expect(client_stub).to receive(:upload) { |_arg| faraday_response }
      messager_instance = instance_double(AppealsApi::Slack::Messager)
      allow(AppealsApi::Slack::Messager).to receive(:new).and_return(messager_instance)
      allow(messager_instance).to receive(:notify!).and_return(true)
      described_class.new.perform(notice_of_disagreement.id, 'AppealsApi::NoticeOfDisagreement')
      expect(notice_of_disagreement.reload.status).to eq('error')
      expect(notice_of_disagreement.code).to eq('DOC201')
    end

    it 'sends a retry notification' do
      Timecop.freeze do
        expect(client_stub).to receive(:upload) { |_arg| faraday_response }
        messager_instance = instance_double(AppealsApi::Slack::Messager)
        allow(AppealsApi::Slack::Messager).to receive(:new).with(
          {
            'class' => described_class.name,
            'args' => [notice_of_disagreement.id, 'AppealsApi::NodPdfSubmitWrapper',
                       notice_of_disagreement.created_at.iso8601],
            'error_class' => 'DOC201',
            'error_message' => 'Downstream status: 501 - ',
            'failed_at' => Time.zone.now
          }, notification_type: :error_retry
        ).and_return(messager_instance)

        allow(messager_instance).to receive(:notify!).and_return(true)
        described_class.new.perform(notice_of_disagreement.id, 'AppealsApi::NoticeOfDisagreement')

        expect(messager_instance).to have_received(:notify!)
      end
    end
  end

  context 'with a duplicate UUID response from Central Mail' do
    before do
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(faraday_response)
        .to receive_messages(status: 400,
                             body: "Document already uploaded with uuid [uuid: #{higher_level_review.id}]",
                             success?: false)
      expect(client_stub).to receive(:upload).and_return(faraday_response)
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:warn)
    end

    it 'sets the appeal status to submitted' do
      described_class.new.perform(higher_level_review.id, 'AppealsApi::HigherLevelReview', 'V2')
      expect(higher_level_review.reload.status).to eq('submitted')
    end

    it 'increments the StatsD duplicate UUID counter' do
      described_class.new.perform(higher_level_review.id, 'AppealsApi::HigherLevelReview', 'V2')
      expect(StatsD).to have_received(:increment).with(described_class::STATSD_DUPLICATE_UUID_KEY)
    end

    it 'logs a duplicate UUID warning' do
      described_class.new.perform(higher_level_review.id, 'AppealsApi::HigherLevelReview', 'V2')
      expect(Rails.logger).to have_received(:warn)
        .with('AppealsApi HlrPdfSubmitWrapper: Duplicate UUID submitted to Central Mail',
              'uuid' => higher_level_review.id)
    end
  end

  context 'an error throws' do
    it 'updates the NOD status to reflect the error' do
      submit_job_worker = described_class.new
      allow(submit_job_worker).to receive(:upload_to_central_mail).and_raise(RuntimeError, 'runtime error!')

      expect do
        submit_job_worker.perform(notice_of_disagreement.id, 'AppealsApi::NoticeOfDisagreement')
      end.to raise_error(RuntimeError, 'runtime error!')

      notice_of_disagreement.reload
      expect(notice_of_disagreement.status).to eq('error')
      expect(notice_of_disagreement.code).to eq('RuntimeError')
    end
  end
end
