# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require 'claims_api/v1/disability_compensation_pdf_generator'
require 'fes_service/base'

RSpec.describe ClaimsApi::V1::Form526EstablishmentUpload, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    stub_claims_api_auth_token
  end

  let(:user) { create(:user, :loa3) }

  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:claim_date) { (Time.zone.today - 1.day).to_s }
  let(:anticipated_separation_date) { 2.days.from_now.strftime('%m-%d-%Y') }

  let(:fes_auth_headers) do
    # NEW: FES headers (copied from service spec)
    { 'va_eauth_csid' => 'DSLogon', 'va_eauth_authenticationmethod' => 'DSLogon', 'va_eauth_pnidtype' => 'SSN',
      'va_eauth_assurancelevel' => '3', 'va_eauth_firstName' => 'Pauline', 'va_eauth_lastName' => 'Foster',
      'va_eauth_issueinstant' => '2025-08-19T13:57:05Z', 'va_eauth_dodedipnid' => '1243413229',
      'va_eauth_birlsfilenumber' => '123456', 'va_eauth_pid' => '600049703', 'va_eauth_pnid' => '796330625',
      'va_eauth_birthdate' => '1976-06-09T00:00:00+00:00',
      'va_eauth_authorization' => '{"authorizationResponse":{"status":"VETERAN","idType":"SSN","id":"796330625",' \
                                  '"edi":"1243413229","firstName":"Pauline","lastName":"Foster", ' \
                                  '"birthDate":"1976-06-09T00:00:00+00:00",' \
                                  '"gender":"MALE"}}', 'va_eauth_authenticationauthority' => 'eauth',
      'va_eauth_service_transaction_id' => '00000000-0000-0000-0000-000000000000' }
  end

  let(:form_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v1', 'veterans', 'disability_compensation',
                           'form_526_json_api.json').read
    temp = JSON.parse(temp)
    attributes = temp['data']['attributes']
    attributes['claimDate'] = claim_date
    attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date

    temp['data']['attributes']
  end

  let(:min_fes_form_data) do
    # NEW: minimal v1 FES payload (copied from service spec)
    {
      claimProcessType: 'STANDARD_CLAIM_PROCESS',
      veteranIdentification: {
        mailingAddress: {
          addressLine1: '1234 Couch Street',
          city: 'Portland', state: 'OR', country: 'USA', zipFirstFive: '12345'
        },
        currentVaEmployee: false
      },
      disabilities: [{ name: 'hearing loss', serviceRelevance: 'Heavy equipment operator in service',
                       approximateDate: '2017-07', disabilityActionType: 'NEW' }],
      serviceInformation: {
        servicePeriods: [
          { serviceBranch: 'Air Force', serviceComponent: 'Active',
            activeDutyBeginDate: '2015-11-14', activeDutyEndDate: '2018-11-30' }
        ]
      },
      claimantCertification: true
    }
  end

  let(:claim) do
    claim = create(:auto_established_claim, form_data: min_fes_form_data)
    claim.transaction_id = '00000000-0000-0000-0000-000000000000'
    claim.auth_headers = fes_auth_headers
    claim.save
    claim
  end

  let(:claim_with_evss_response) do
    claim = create(:auto_established_claim, form_data: min_fes_form_data)
    claim.transaction_id = '00000000-0000-0000-0000-000000000000'
    claim.auth_headers = fes_auth_headers
    claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
    claim.evss_response = 'Just a test evss error response'
    claim.save
    claim
  end

  let(:errored_claim) do
    claim = create(:auto_established_claim, form_data: min_fes_form_data)
    claim.transaction_id = '00000000-0000-0000-0000-000000000000'
    claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
    claim.auth_headers = fes_auth_headers
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
        VCR.use_cassette('claims_api/fes/submit') do
          expect(errored_claim.status).to eq('errored')

          service.perform(errored_claim.id)

          errored_claim.reload
          expect(errored_claim.status).to eq('pending')
        end
      end

      it 'removes the evss_response on successful docker Container submission' do
        VCR.use_cassette('claims_api/fes/submit') do
          expect(claim_with_evss_response.status).to eq('errored')
          expect(claim_with_evss_response.evss_response).to eq('Just a test evss error response')

          service.perform(claim_with_evss_response.id)

          claim_with_evss_response.reload
          expect(claim_with_evss_response.status).to eq('pending')
          expect(claim_with_evss_response.evss_response).to be_nil
        end
      end
    end

    context 'errored submission' do
      before do
        @should_retry = false
      end

      it 'does not call the next job when the claim.status is errored' do
        VCR.use_cassette('claims_api/fes/submit') do
          allow(errored_claim).to receive(:status).and_return('errored')

          service.perform(errored_claim.id)

          errored_claim.reload
          expect(service).not_to receive(:start_bd_uploader_job)
        end
      end

      it 'updates the evss_response with the error message' do
        body = [{ key: 'form526.submit.establishClaim.serviceError',
                  severity: 'FATAL',
                  text: 'Error calling external service to establish the claim during submit.' }]

        # Rubocop formatting
        allow_any_instance_of(ClaimsApi::FesService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.submit.establishClaim.serviceError', {}, nil, body
                                     ))
        )

        Sidekiq::Testing.inline! do
          expect do
            subject.perform_async(errored_claim.id)
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end

        errored_claim.reload
        # rubocop:disable Layout/LineLength
        expect(errored_claim.evss_response).to eq([{ 'key' => 'form526.submit.establishClaim.serviceError',
                                                     'severity' => 'FATAL',
                                                     'text' => 'Error calling external service to establish the claim during submit.' }])
        # rubocop:enable Layout/LineLength
      end

      it 'does not retry when form526.submit.noRetryError error gets returned' do
        body = [{
          key: 'form526.submit.noRetryError',
          severity: 'FATAL',
          text: 'Claim could not be established. Retries will fail.'
        }]

        error = Common::Exceptions::BackendServiceException.new(
          'form526.submit.noRetryError', {}, nil, body
        )

        allow_any_instance_of(ClaimsApi::FesService::Base).to(
          receive(:submit).and_raise(error)
        )

        Sidekiq::Testing.inline! do
          expect do
            subject.perform_async(claim.id)
          end.not_to raise_error
        end

        claim.reload

        @should_retry = service.send(:will_retry?, claim, error)

        expect(claim.status).to eq('errored')
        expect(claim.evss_response).to eq([{ 'key' => 'form526.submit.noRetryError',
                                             'severity' => 'FATAL',
                                             'text' => 'Claim could not be established. Retries will fail.' }])
        expect(@should_retry).to be(false)
      end

      it 'does not retry when form526.InProcess error gets returned' do
        body = [{ key: 'form526.InProcess',
                  severity: 'FATAL',
                  text: 'Form 526 is already in-process.' }]

        error = Common::Exceptions::BackendServiceException.new(
          'form526.InProcess', {}, nil, body
        )

        allow_any_instance_of(ClaimsApi::FesService::Base).to(
          receive(:submit).and_raise(error)
        )

        Sidekiq::Testing.inline! do
          expect do
            subject.perform_async(claim.id)
          end.not_to raise_error
        end

        claim.reload

        @should_retry = service.send(:will_retry?, claim, error)

        expect(claim.status).to eq('errored')
        expect(claim.evss_response).to eq([{ 'key' => 'form526.InProcess',
                                             'severity' => 'FATAL',
                                             'text' => 'Form 526 is already in-process.' }])
        expect(@should_retry).to be(false)
      end

      it 'does retry when form526.submit.establishClaim.serviceError gets returned' do
        body =
          [{
            key: 'form526.submit.establishClaim.serviceError',
            severity: 'FATAL',
            text: 'Error calling external service to establish the claim during submit.'
          }]

        allow_any_instance_of(ClaimsApi::FesService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       'form526.submit.establishClaim.serviceError', {}, nil, body
                                     ))
        )

        Sidekiq::Testing.inline! do
          expect do
            subject.perform_async(claim.id)
          end.to raise_error(Common::Exceptions::BackendServiceException) { |error|
            # Capture the behavior of will_retry? method when the exception is raised
            claim.reload
            @should_retry = service.send(:will_retry?, claim, error)
          }
        end

        claim.reload
        # rubocop:disable Layout/LineLength
        expect(claim.evss_response).to eq([{ 'key' => 'form526.submit.establishClaim.serviceError',
                                             'severity' => 'FATAL',
                                             'text' => 'Error calling external service to establish the claim during submit.' }])
        # rubocop:enable Layout/LineLength
        expect(@should_retry).to be(true)
      end

      it "does not retry when the message key is 'in progress' and are in an array" do
        body = [{ key: 'form526.InProcess', severity: 'FATAL', text: 'Form 526 is already in-process' }]

        error = Common::Exceptions::BackendServiceException.new(
          'form526.InProcess', {}, nil, body
        )

        allow_any_instance_of(ClaimsApi::FesService::Base).to(
          receive(:submit).and_raise(error)
        )

        Sidekiq::Testing.inline! do
          expect do
            subject.perform_async(claim.id)
          end.not_to raise_error
        end

        claim.reload

        @should_retry = service.send(:will_retry?, claim, error)

        expect(claim.status).to eq('errored')
        expect(claim.evss_response).to eq([{ 'key' => 'form526.InProcess', 'severity' => 'FATAL',
                                             'text' => 'Form 526 is already in-process' }])
        expect(@should_retry).to be(false)
      end

      it 'does retry when 5xx error gets returned' do
        body = [{
          key: '',
          severity: 'FATAL',
          text: 'Error calling external service to establish the claim during submit.'
        }]
        # Rubocop formatting
        allow_any_instance_of(ClaimsApi::FesService::Base).to(
          receive(:submit).and_raise(Common::Exceptions::BackendServiceException.new(
                                       '', {}, nil, body
                                     ))
        )

        Sidekiq::Testing.inline! do
          expect do
            subject.perform_async(claim.id)
          end.to raise_error(Common::Exceptions::BackendServiceException) { |error|
            claim.reload
            @should_retry = service.send(:will_retry?, claim, error)
          }
        end

        claim.reload
        expect(claim.status).to eq('errored')
        # rubocop:disable Layout/LineLength
        expect(claim.evss_response).to eq([{ 'key' => '',
                                             'severity' => 'FATAL',
                                             'text' => 'Error calling external service to establish the claim during submit.' }])
        # rubocop:enable Layout/LineLength
        expect(@should_retry).to be(true)
      end

      it 'logs BackendServiceException errors at ERROR level via log_exception_to_rails' do
        body = [{
          key: 'form526.submit.establishClaim.serviceError',
          severity: 'FATAL',
          text: 'Error calling external service to establish the claim during submit.'
        }]

        backend_error = Common::Exceptions::BackendServiceException.new(
          'form526.submit.establishClaim.serviceError', {}, nil, body
        )

        allow_any_instance_of(ClaimsApi::FesService::Base).to receive(:submit).and_raise(backend_error)

        # Spy on the service instance to verify log_exception_to_rails is called
        allow(service).to receive(:log_exception_to_rails).and_call_original

        Sidekiq::Testing.inline! do
          expect do
            service.perform(claim.id)
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end

        # Verify that log_exception_to_rails was called with the BackendServiceException
        expect(service).to have_received(:log_exception_to_rails).with(backend_error)
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

  describe 'when an errored job has a time limitation' do
    it 'logs to the ClaimsApi Logger' do
      described_class.within_sidekiq_retries_exhausted_block do
        expect(subject).to be_expired_in 48.hours
      end
    end
  end
end
