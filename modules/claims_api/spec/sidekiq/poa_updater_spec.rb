# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::PoaUpdater, type: :job, vcr: 'bgs/person_web_service/find_by_ssn' do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).with(:claims_api_use_vet_record_service).and_return false
    allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return false
    allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return false
  end

  let(:user) { create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  context "when call to BGS 'update_birls_record' is successful" do
    context 'and the poaCode is retrieved successfully from the V2 2122a form data' do
      it "does not update the form's status and creates 'ClaimsApi::PoaVBMSUpdater' job" do
        allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return false
        create_mock_lighthouse_service
        expect(ClaimsApi::PoaVBMSUpdater).to receive(:perform_async)

        poa = create_poa
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

        subject.new.perform(poa.id)
        poa.reload
        expect(poa.status).to eq('pending')
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
    it "updates the form's status and does not create a 'ClaimsApi::PoaVBMSUpdater' job" do
      create_mock_lighthouse_service
      allow_any_instance_of(BGS::VetRecordWebService).to receive(:update_birls_record).and_return(
        return_code: 'some error code'
      )
      expect(ClaimsApi::PoaVBMSUpdater).not_to receive(:perform_async)

      poa = create_poa

      subject.new.perform(poa.id)
      poa.reload
      expect(poa.status).to eq('errored')
    end
  end

  context 'deciding to send a VA Notify email' do
    before do
      create_mock_lighthouse_service
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return true
    end

    let(:poa) { create_poa }
    let(:header_key) { ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController::VA_NOTIFY_KEY }

    context 'when the header key and rep are present' do
      it 'sends the vanotify job' do
        poa.auth_headers.merge!({
                                  header_key => 'this_value'
                                })
        poa.save!

        allow_any_instance_of(ClaimsApi::ServiceBase).to receive(:vanotify?).and_return true
        expect(ClaimsApi::VANotifyAcceptedJob).to receive(:perform_async)

        subject.new.perform(poa.id, 'Rep Data')
      end
    end

    context 'when the flipper is off' do
      it 'does not send the vanotify job' do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return false
        Flipper.disable(:lighthouse_claims_api_v2_poa_va_notify)

        poa.auth_headers.merge!({
                                  header_key => 'this_value'
                                })
        poa.save!

        expect(ClaimsApi::VANotifyAcceptedJob).not_to receive(:perform_async)

        subject.new.perform(poa.id, 'Rep Data')
      end
    end

    context 'does not send the va notify job' do
      it 'when the rep is not present' do
        poa.auth_headers.merge!({
                                  header_key => 'this_value'
                                })
        poa.save!

        expect(ClaimsApi::VANotifyAcceptedJob).not_to receive(:perform_async)

        subject.new.perform(poa.id, nil)
      end

      it 'when the header key is not present' do
        expect(ClaimsApi::VANotifyAcceptedJob).not_to receive(:perform_async)

        subject.new.perform(poa.id, 'Rep data')
      end
    end
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

    before do
      allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return true
      allow(ClaimsApi::PersonWebService).to receive(:new).with(external_uid: anything,
                                                               external_key: anything)
                                                         .and_return(person_web_service)
      allow(person_web_service).to receive(:find_by_ssn).and_return({ file_nbr: '796111863' })
    end

    it 'calls local bgs person web service instead of bgs-ext' do
      poa = create_poa
      subject.new.perform(poa.id)

      expect(person_web_service).to have_received(:find_by_ssn)
    end
  end

  describe 'when the claims_api_use_vet_record_service flipper is on' do
    let(:vet_record_web_service) { instance_double(ClaimsApi::VetRecordWebService) }

    before do
      allow(Flipper).to receive(:enabled?).with(:claims_api_use_vet_record_service).and_return true
      allow(ClaimsApi::VetRecordWebService).to receive(:new).with(external_uid: anything,
                                                                  external_key: anything)
                                                            .and_return(vet_record_web_service)
      allow(vet_record_web_service).to receive(:update_birls_record).and_return({ return_code: 'BMOD0001' })
    end

    it 'calls local bgs vet record service instead of bgs-ext' do
      poa = create_poa
      subject.new.perform(poa.id)

      expect(vet_record_web_service).to have_received(:update_birls_record)
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
