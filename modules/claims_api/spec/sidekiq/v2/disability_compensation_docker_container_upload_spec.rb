# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require 'claims_api/v2/disability_compensation_pdf_generator'

RSpec.describe ClaimsApi::V2::DisabilityCompensationDockerContainerUpload, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    stub_claims_api_auth_token
  end

  let(:user) { FactoryBot.create(:user, :loa3) }

  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:claim_date) { (Time.zone.today - 1.day).to_s }
  let(:anticipated_separation_date) { 2.days.from_now.strftime('%m-%d-%Y') }

  let(:form_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                           'form_526_json_api.json').read
    temp = JSON.parse(temp)
    attributes = temp['data']['attributes']
    attributes['claimDate'] = claim_date
    attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date

    temp['data']['attributes']
  end

  let(:claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  let(:claim_with_evss_response) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
    claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
    claim.evss_response = 'Just a test evss error response'
    claim.save
    claim
  end

  let(:errored_claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  describe '#perform' do
    service = described_class.new

    context 'successful submission' do
      it 'queues the job' do
        expect do
          subject.perform_async(claim.id)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'sets the claim status to pending when starting/rerunning' do
        VCR.use_cassette('claims_api/evss/submit') do
          expect(errored_claim.status).to eq('errored')

          service.perform(errored_claim.id)

          errored_claim.reload
          expect(errored_claim.status).to eq('pending')
        end
      end

      it 'removes the evss_response on successful docker Container submission' do
        VCR.use_cassette('claims_api/evss/submit') do
          expect(claim_with_evss_response.status).to eq('errored')
          expect(claim_with_evss_response.evss_response).to eq('Just a test evss error response')

          service.perform(claim_with_evss_response.id)

          claim_with_evss_response.reload
          expect(claim_with_evss_response.status).to eq('pending')
          expect(claim_with_evss_response.evss_response).to eq(nil)
        end
      end

      it 'does retry when form526.submit.establshClaim.serviceError gets returned' do
        body = {
          messages: [
            { key: 'form526.submit.establshClaim.serviceError',
              severity: 'FATAL',
              text: 'Error calling external service to establish the claim during submit.' }
          ]
        }

        allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.submit.establshClaim.serviceError', {}, nil, body
                                     ))
        )

        expect do
          service.perform(claim.id)
        end.to raise_error(Common::Exceptions::BackendServiceException)
      end

      it "does not retry when the message key is 'in progress' and are in an array" do
        body = {
          messages: [{ key: 'form526.InProcess', severity: 'FATAL', text: 'Form 526 is already in-process' }]
        }

        allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.submit.establshClaim.serviceError', {}, nil, body
                                     ))
        )
        expect do
          service.perform(claim_with_evss_response.id)
        end.to raise_error(Common::Exceptions::BackendServiceException)
        claim_with_evss_response.reload

        expect(claim_with_evss_response.status).to eq('errored')
        expect(claim_with_evss_response.evss_response).to eq({ 'messages' =>
        [{ 'key' => 'form526.InProcess', 'severity' => 'FATAL', 'text' => 'Form 526 is already in-process' }] })
      end

      it 'does retry when the message indicates a birls error and is in an array' do
        body = {
          messages: [
            {
              'key' => 'header.va_eauth_birlsfilenumber.Invalid',
              'severity' => 'ERROR',
              'text' => 'Size must be between 8 and 9'
            }
          ]
        }

        allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.submit.establshClaim.serviceError', {}, nil, body
                                     ))
        )
        claim_with_evss_response.reload
        expect do
          service.perform(claim.id)
        end.to raise_error(Common::Exceptions::BackendServiceException)
        expect(claim_with_evss_response.status).to eq('errored')
      end

      it 'does retry when the message indicates a birls error and is NOT in an array' do
        body = { key: 'header.va_eauth_birlsfilenumber', severity: 'ERROR',
                 text: 'Size must be between 8 and 9' }

        allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.submit.establshClaim.serviceError', {}, nil, body
                                     ))
        )
        claim_with_evss_response.reload
        expect do
          service.perform(claim.id)
        end.to raise_error(Common::Exceptions::BackendServiceException)
        expect(claim_with_evss_response.status).to eq('errored')
      end

      it 'does not retry when the message indicates a birls error and is an array of many messages' do
        body = {
          messages: [
            { key: 'header.va_eauth_birlsfilenumber', severity: 'ERROR',
              text: 'Size must be between 8 and 9' },
            { key: 'form526.InProcess', severity: 'FATAL', text: 'Form 526 is already in-process' }
          ]
        }

        allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.submit.establshClaim.serviceError', {}, nil, body
                                     ))
        )
        claim_with_evss_response.reload
        expect do
          service.perform(claim.id)
        end.to raise_error(Common::Exceptions::BackendServiceException)
        expect(claim_with_evss_response.status).to eq('errored')
      end
    end

    context 'errored submission' do
      it 'does not call the next job when the claim.status is errored' do
        VCR.use_cassette('claims_api/evss/submit') do
          allow(errored_claim).to receive(:status).and_return('errored')

          service.perform(errored_claim.id)

          errored_claim.reload
          expect(service).not_to receive(:start_bd_uploader_job)
        end
      end

      it 'updates the evss_response with the error message' do
        body = {
          messages: [
            { key: 'form526.submit.noRetryError',
              severity: 'FATAL',
              text: 'Claim could not be established. Retries will fail.' }
          ]
        }
        # Rubocop formatting
        allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.submit.noRetryError', {}, nil, body
                                     ))
        )
        expect do
          service.perform(errored_claim.id)
        end.to raise_error(Common::Exceptions::BackendServiceException)
        errored_claim.reload
        expect(errored_claim.evss_response).to eq({ 'messages' =>
          [{ 'key' => 'form526.submit.noRetryError', 'severity' => 'FATAL',
             'text' => 'Claim could not be established. Retries will fail.' }] })
      end

      it 'does not retry when form526.submit.noRetryError error gets returned' do
        body = {
          messages: [
            { key: 'form526.submit.noRetryError',
              severity: 'FATAL',
              text: 'Claim could not be established. Retries will fail.' }
          ]
        }
        # Rubocop formatting
        jobs = subject.jobs.size
        allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.submit.noRetryError', {}, nil, body
                                     ))
        )
        expect do
          service.perform(claim.id)
        end.to raise_error(Common::Exceptions::BackendServiceException)
        expect(jobs).to eq(subject.jobs.size)
      end

      it 'does not retry when form526.InProcess error gets returned' do
        body = {
          messages: [
            { key: 'form526.InProcess',
              severity: 'FATAL',
              text: 'Form 526 is already in-process' }
          ]
        }
        # Rubocop formatting
        jobs = subject.jobs.size
        allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.InProcess', {}, nil, body
                                     ))
        )
        expect do
          service.perform(claim.id)
        end.to raise_error(Common::Exceptions::BackendServiceException)
        expect(jobs).to eq(subject.jobs.size)
      end

      it 'does retry when 5xx error gets returned' do
        body = {
          messages: [
            { key: '',
              severity: 'FATAL',
              text: 'Error calling external service to establish the claim during submit.' }
          ]
        }
        # Rubocop formatting
        allow_any_instance_of(ClaimsApi::EVSSService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       '', {}, nil, body
                                     ))
        )

        expect do
          service.perform(claim.id)
        end.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Docker Container Upload Job'
      msg = { 'args' => [claim.id],
              'class' => subject,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: claim.id,
          detail: "Job retries exhausted for #{subject}",
          error: error_msg
        )
      end
    end
  end
end
