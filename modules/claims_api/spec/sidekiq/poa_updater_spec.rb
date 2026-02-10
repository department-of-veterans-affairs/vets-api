# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/bgs_error_helpers'

RSpec.describe ClaimsApi::PoaUpdater, type: :job, vcr: 'bgs/person_web_service/find_by_ssn' do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).with(:claims_api_use_update_poa_relationship).and_return false
    allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return false
    allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return false
  end

  let(:user) { create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  it 'sets retry_for to 48 hours' do
    expect(described_class.get_sidekiq_options['retry_for']).to eq(48.hours)
  end

  context "when call to BGS 'update_birls_record' is successful" do
    context 'and the poaCode is retrieved successfully from the V2 2122a form data' do
      let(:poa) { create_poa }

      before do
        allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return false
        create_mock_lighthouse_service
        poa.form_data = {
          representative: {
            poaCode: '072',
            firstName: 'my',
            lastName: 'name',
            type: 'ATTORNEY',
            address: {
              numberAndStreet: '123',
              city: 'city',
              country: 'US',
              zipFirstFive: '12345'
            }
          },
          recordConsent: true,
          consentLimits: []
        }
        poa.status = 'pending'
        poa.save!
      end

      it "does not update the form's status and creates 'ClaimsApi::PoaVBMSUpdater' job" do
        expect(ClaimsApi::PoaVBMSUpdater).to receive(:perform_async)
        subject.new.perform(poa.id)
        poa.reload
        expect(poa.status).to eq('pending')
      end

      it 'updates the process status to SUCCESS' do
        subject.new.perform(poa.id)
        process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_UPDATE')
        expect(process.step_status).to eq('SUCCESS')
      end
    end

    context 'and record consent is granted' do
      it "creates 'ClaimsApi::PoaVBMSUpdater' job" do
        create_mock_lighthouse_service
        expect(ClaimsApi::PoaVBMSUpdater).to receive(:perform_async)

        poa = create_poa
        poa.form_data.merge!({ recordConsent: true, consentLimits: [] })
        poa.save!

        subject.new.perform(poa.id)
      end
    end
  end

  context "when call to BGS 'update_birls_record' fails" do
    let(:poa) { create_poa }

    before do
      create_mock_lighthouse_service
    end

    context 'with a response indicating failure' do
      before do
        allow_any_instance_of(BGS::VetRecordWebService).to receive(:update_birls_record).and_return(
          return_code: 'some error code'
        )
      end

      it "updates the form's status and does not create a 'ClaimsApi::PoaVBMSUpdater' job" do
        expect(ClaimsApi::PoaVBMSUpdater).not_to receive(:perform_async)
        subject.new.perform(poa.id)
        poa.reload
        expect(poa.status).to eq('errored')
      end

      it 'updates the process status to FAILED' do
        subject.new.perform(poa.id)
        process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_UPDATE')
        expect(process.step_status).to eq('FAILED')
      end
    end

    # run error handling shared examples for BGS service errors and standard errors
    include_examples 'BGS service error handling', BGS::VetRecordWebService, :update_birls_record

    include_examples 'standard error handling', BGS::VetRecordWebService, :update_birls_record
  end

  context 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      poa = create_poa
      error_msg = 'An error occurred in the POA Updater Job'
      msg = { 'args' => [poa.id],
              'class' => subject,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: poa.id,
          detail: "Job retries exhausted for #{subject}",
          error: error_msg
        )
      end
    end
  end

  describe 'when the claims_api_use_person_web_service flipper is on' do
    let(:person_web_service) { instance_double(ClaimsApi::PersonWebService) }
    let(:poa) { create_poa }

    before do
      allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return true
      allow(ClaimsApi::PersonWebService).to receive(:new).with(external_uid: anything,
                                                               external_key: anything)
                                                         .and_return(person_web_service)
    end

    context 'and the PersonWebService retrieves successfully' do
      before do
        allow(person_web_service).to receive(:find_by_ssn).and_return({ file_nbr: '796111863' })
      end

      it 'calls local bgs person web service instead of bgs-ext' do
        subject.new.perform(poa.id)

        expect(person_web_service).to have_received(:find_by_ssn)
      end
    end

    context 'and the PersonWebService raises an exception' do
      # run error handling shared examples for BGS service errors and standard errors
      include_examples 'BGS service error handling with instance double', :person_web_service, :find_by_ssn

      include_examples 'standard error handling with instance double', :person_web_service, :find_by_ssn
    end
  end

  describe 'when the claims_api_use_update_poa_relationship flipper is on' do
    let(:manage_rep_poa_update_service) { instance_double(ClaimsApi::ManageRepresentativeService) }
    let(:poa) { create_poa }

    let(:successful_response) do
      {
        'dateRequestAccepted' => '2025-01-30T00:00:00-06:00',
        'relationshipType' => 'Power of Attorney For',
        'vetPtcpntId' => '600049322',
        'vsoPOACode' => '045',
        'vsoPtcpntId' => '45973'
      }
    end

    before do
      allow(Flipper).to receive(:enabled?).with(:claims_api_use_update_poa_relationship).and_return true
      allow(ClaimsApi::ManageRepresentativeService).to receive(:new).with(external_uid: anything,
                                                                          external_key: anything)
                                                                    .and_return(manage_rep_poa_update_service)
    end

    context 'and the ManageRepresentativeService retrieves successfully' do
      before do
        allow(manage_rep_poa_update_service).to receive(:update_poa_relationship).and_return(successful_response)
      end

      it 'calls local bgs vet record service instead of bgs-ext' do
        subject.new.perform(poa.id)

        expect(manage_rep_poa_update_service).to have_received(:update_poa_relationship)
      end
    end

    context 'and the ManageRepresentativeService raises an exception' do
      # run error handling shared examples for BGS service errors and standard errors
      include_examples 'BGS service error handling with instance double',
                       :manage_rep_poa_update_service,
                       :update_poa_relationship

      include_examples 'standard error handling with instance double',
                       :manage_rep_poa_update_service,
                       :update_poa_relationship
    end
  end

  private

  def create_poa
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    poa.save
    poa
  end

  def create_mock_lighthouse_service
    allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
    allow_any_instance_of(BGS::VetRecordWebService).to receive(:update_birls_record)
      .and_return({ return_code: 'BMOD0001' })
  end
end
