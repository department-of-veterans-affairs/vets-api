# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require 'claims_api/v1/disability_compensation_pdf_generator'

RSpec.describe ClaimsApi::V1::DisabilityCompensationPdfGenerator, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    stub_claims_api_auth_token
  end

  let(:user) { create(:user, :loa3) }

  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:form_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
    temp = JSON.parse(temp)
    temp['data']['attributes']

    temp['data']['attributes']
  end

  let(:claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  let(:pending_claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.status = ClaimsApi::AutoEstablishedClaim::PENDING
    claim.auth_headers = auth_headers
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
    let(:middle_initial) { '' }

    service = described_class.new

    context 'handles a successful claim correctly' do
      it 'submits successfully' do
        expect do
          subject.perform_async(claim.id, middle_initial)
        end.to change(subject.jobs, :size).by(1)
      end

      context 'sets the status on the claim as expected' do
        it 'does not set status when claim.status is PENDING' do
          VCR.use_cassette('claims_api/disability_comp') do
            expect_any_instance_of(subject).not_to receive(:set_pending_state_on_claim)

            service.perform(pending_claim.id, middle_initial)
          end
        end

        it 'sets the claim status to pending when starting/rerunning' do
          VCR.use_cassette('claims_api/disability_comp') do
            expect(errored_claim.status).to eq('errored')

            service.perform(errored_claim.id, middle_initial)

            errored_claim.reload
            expect(errored_claim.status).to eq('pending')
          end
        end
      end

      context 'mocking' do
        before do
          allow(Settings.claims_api.benefits_documents).to receive(:use_mocks).and_return(true)
        end

        it 'calls the Docker Container Job up front when mocking is enabled' do
          job_instance = described_class.new

          expect(job_instance).not_to receive(:set_pending_state_on_claim)
          expect(job_instance).not_to receive(:pdf_mapper_service)
          expect(job_instance).not_to receive(:generate_526_pdf)
          expect(job_instance).to receive(:start_docker_container_job).with(claim.id).once

          job_instance.perform(claim.id, middle_initial)
        end
      end
    end

    context 'handles an errored claim correctly' do
      it 'sets claim state to errored when pdf_string is empty' do
        VCR.use_cassette('claims_api/disability_comp') do
          allow(service).to receive(:generate_526_pdf).and_return('')

          service.perform(claim.id, middle_initial)

          claim.reload
          expect(claim.status).to eq('errored')
        end
      end

      it 'does not call the next job when the claim.status is errored' do
        VCR.use_cassette('claims_api/disability_comp') do
          allow(service).to receive(:generate_526_pdf).and_return('')

          service.perform(claim.id, middle_initial)

          claim.reload
          expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
          expect(service).not_to receive(:start_docker_container_job)
        end
      end

      it 'calls the next job when the claim.status is not errored' do
        VCR.use_cassette('claims_api/disability_comp') do
          allow(service).to receive(:generate_526_pdf).and_return('This is a pdf string value')
          expect_any_instance_of(described_class).to receive(:start_docker_container_job).with(claim.id).once

          service.perform(claim.id, middle_initial)

          claim.reload
          expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::PENDING)
        end
      end

      context 'when an error is raised' do
        context 'Faraday::ParsingError' do
          let(:errors) do
            [{ 'title' => 'Operation failed', 'detail' => 'Operation failed', 'code' => 'VA900', 'status' => '400' }]
          end

          before do
            allow(Settings.claims_api.benefits_documents).to receive(:use_mocks).and_return(true)
          end

          it 'set the errored state, saves the response and logs the progress, in that order' do
            allow(service).to receive(:set_errored_state_on_claim)
            allow(service).to receive(:set_evss_response)
            allow(service).to receive(:get_error_status_code)
            allow(service).to receive(:log_job_progress)
            allow(service).to receive(:start_docker_container_job).and_raise(
              Faraday::ParsingError.new(errors)
            )

            expect do
              service.perform(claim.id, middle_initial)
            end.to raise_error(Faraday::ParsingError)
            # this order matters, we need to set the state first thing in case anything else errors out
            expect(service).to have_received(:set_errored_state_on_claim).with(claim).ordered
            expect(service).to have_received(:set_evss_response).with(claim, kind_of(
                                                                               Faraday::ParsingError
                                                                             )).ordered
            expect(service).to have_received(:get_error_status_code).with(kind_of(
                                                                            Faraday::ParsingError
                                                                          )).ordered
            expect(service).to have_received(:log_job_progress).twice
          end
        end

        context '::Common::Exceptions::BackendServiceException' do
          let(:errors) do
            [{ 'title' => 'Operation failed', 'detail' => 'Operation failed', 'code' => 'VA900', 'status' => '400' }]
          end

          before do
            allow(Settings.claims_api.benefits_documents).to receive(:use_mocks).and_return(true)
          end

          it 'set the errored state, saves the response and logs the progress, in that order' do
            allow(service).to receive(:set_errored_state_on_claim)
            allow(service).to receive(:set_evss_response)
            allow(service).to receive(:get_error_status_code)
            allow(service).to receive(:log_job_progress)
            allow(service).to receive(:start_docker_container_job).and_raise(
              Common::Exceptions::BackendServiceException.new(errors)
            )

            expect do
              service.perform(claim.id, middle_initial)
            end.to raise_error(Common::Exceptions::BackendServiceException)
            # this order matters, we need to set the state first thing in case anything else errors out
            expect(service).to have_received(:set_errored_state_on_claim).with(claim).ordered
            expect(service).to have_received(:set_evss_response).with(claim, kind_of(
                                                                               Common::Exceptions::BackendServiceException
                                                                             )).ordered
            expect(service).to have_received(:get_error_status_code).with(kind_of(
                                                                            Common::Exceptions::BackendServiceException
                                                                          )).ordered
            expect(service).to have_received(:log_job_progress).twice
          end
        end

        context 'General Rescue' do
          let(:errors) do
            [{ 'title' => 'Operation failed', 'detail' => 'Operation failed', 'code' => 'VA900', 'status' => '400' }]
          end

          before do
            allow(Settings.claims_api.benefits_documents).to receive(:use_mocks).and_return(true)
          end

          it 'set the errored state, saves the response and logs the progress, in that order' do
            allow(service).to receive(:set_errored_state_on_claim)
            allow(service).to receive(:set_evss_response)
            allow(service).to receive(:log_job_progress)
            allow(service).to receive(:start_docker_container_job).and_raise(
              NoMethodError.new(errors)
            )

            expect do
              service.perform(claim.id, middle_initial)
            end.to raise_error(NoMethodError)
            # this order matters, we need to set the state first thing in case anything else errors out
            expect(service).to have_received(:set_errored_state_on_claim).with(claim).ordered
            expect(service).to have_received(:set_evss_response).with(claim, kind_of(
                                                                               NoMethodError
                                                                             )).ordered
            expect(service).to have_received(:log_job_progress).twice
          end
        end
      end
    end
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the PDF Generator Job'
      msg = { 'args' => [claim.id, ''],
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
