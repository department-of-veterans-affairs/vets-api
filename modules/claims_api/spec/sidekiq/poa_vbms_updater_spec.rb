# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/corporate_update_web_service'

RSpec.describe ClaimsApi::PoaVBMSUpdater, type: :job do
  subject { described_class }

  [true, false].each do |flipped|
    before do
      Sidekiq::Job.clear_all
      allow(Flipper).to receive(:enabled?).with(:claims_api_poa_vbms_updater_uses_local_bgs).and_return(flipped)
      @clazz = if flipped
                 ClaimsApi::CorporateUpdateWebService
               else
                 BGS::Services
               end
      @corporate_update_stub = if flipped
                                 @clazz.new(external_uid: 'uid', external_key: 'key')
                               else
                                 @clazz.new(external_uid: 'uid', external_key: 'key').corporate_update
                               end
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

    context 'when address change is present and allowed' do
      let(:allow_poa_c_add) { 'Y' }
      let(:consent_address_change) { true }

      it 'updates a the BIRLS record for a qualifying POA submittal' do
        poa = create_poa(allow_poa_access: true)
        create_mock_lighthouse_service
        subject.new.perform(poa.id)
        process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_ACCESS_UPDATE')
        expect(process.step_status).to eq('SUCCESS')
      end
    end

    context 'when address change is present and not allowed' do
      let(:allow_poa_c_add) { 'N' }
      let(:consent_address_change) { false }

      it 'updates a the BIRLS record for a qualifying POA submittal' do
        poa = create_poa(allow_poa_access: true)
        create_mock_lighthouse_service
        subject.new.perform(poa.id)
        process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_ACCESS_UPDATE')
        expect(process.step_status).to eq('SUCCESS')
      end
    end

    context 'consent details' do
      let(:allow_poa_c_add) { 'Y' }
      let(:consent_address_change) { true }

      it 'logs correct with consentLimits included' do
        poa = create_poa(allow_poa_access: true)
        poa.form_data['consentLimits'] = ['HIV']
        poa.save
        create_mock_lighthouse_service_no_access
        poa_code = poa.form_data['serviceOrganization']['poaCode']
        consent_msg = 'Updating Access. recordConsent: true' \
                      ', consentLimits included ' \
                      "for representative #{poa_code}"

        detail_msg = ClaimsApi::ServiceBase.new.send(:form_logger_consent_detail, poa, poa_code)

        expect(detail_msg).to eq(consent_msg)
        subject.new.perform(poa.id)
      end
    end

    context 'when address change is not present' do
      let(:allow_poa_c_add) { 'N' }
      let(:consent_address_change) { nil }

      it 'updates a the BIRLS record for a qualifying POA submittal' do
        poa = create_poa(allow_poa_access: true)
        create_mock_lighthouse_service
        subject.new.perform(poa.id)
        process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_ACCESS_UPDATE')
        expect(process.step_status).to eq('SUCCESS')
      end
    end

    context 'when BGS fails the error is handled' do
      let(:allow_poa_c_add) { 'Y' }
      let(:consent_address_change) { true }

      it 'marks the form as errored' do
        poa = create_poa(allow_poa_access: true)
        create_mock_lighthouse_service_bgs_failure # API-31645 real life example
        subject.new.perform(poa.id)

        poa.reload
        expect(poa.status).to eq('errored')
        expect(poa.vbms_error_message).to eq('updatePoaAccess: No POA found on system of record')
        process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_ACCESS_UPDATE')
        expect(process.step_status).to eq('FAILED')
      end
    end

    context 'deciding to send a VA Notify email' do
      let(:allow_poa_c_add) { 'Y' }
      let(:poa) { create_poa }
      let(:header_key) { ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController::VA_NOTIFY_KEY }
      let(:consent_address_change) { true }

      before do
        create_mock_lighthouse_service
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return true
      end

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
      let(:allow_poa_c_add) { 'Y' }
      let(:consent_address_change) { true }

      it 'logs to the ClaimsApi Logger' do
        poa = create_poa(allow_poa_access: true)
        error_msg = 'An error occurred for the POA VBMS Updater Job'
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
  end

  private

  def create_poa(allow_poa_access: true)
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    if consent_address_change.present?
      poa.form_data = poa.form_data.merge('consentAddressChange' => consent_address_change)
    end
    poa.form_data = poa.form_data.merge('recordConsent' => allow_poa_access)
    poa.save
    poa
  end

  def create_mock_lighthouse_service
    expect(@corporate_update_stub).to receive(:update_poa_access).with(
      participant_id: user.participant_id,
      poa_code: '074',
      allow_poa_access: 'Y',
      allow_poa_c_add:
    ).and_return({ return_code: 'GUIE50000' })
    service_double = instance_double(BGS::Services)
    expect(service_double).to receive(:corporate_update).and_return(@corporate_update_stub)
    expect(BGS::Services).to receive(:new).and_return(service_double)
  end

  def create_mock_lighthouse_service_no_access
    expect(@corporate_update_stub).to receive(:update_poa_access).with(
      participant_id: user.participant_id,
      poa_code: '074',
      allow_poa_access: 'N',
      allow_poa_c_add:
    ).and_return({ return_code: 'GUIE50000' })
    service_double = instance_double(BGS::Services)
    expect(service_double).to receive(:corporate_update).and_return(@corporate_update_stub)
    expect(BGS::Services).to receive(:new).and_return(service_double)
  end

  def create_mock_lighthouse_service_bgs_failure
    allow_any_instance_of(@clazz).to receive(:corporate_update) do |_instance|
      corporate_update_stub = instance_double(BGS::CorporateUpdate)
      allow(corporate_update_stub).to receive(:update_poa_access)
        .with(
          participant_id: user.participant_id,
          poa_code: '074',
          allow_poa_access: 'Y',
          allow_poa_c_add:
        ).and_return({ return_code: 'GUIE50000' })
      corporate_update_stub
    end

    allow(@clazz).to receive(:new) do
      services_double = instance_double(BGS::Services)
      allow(services_double).to receive(:corporate_update)
        .and_raise(BGS::ShareError.new('updatePoaAccess: No POA found on system of record'))
      services_double
    end
  end
end
