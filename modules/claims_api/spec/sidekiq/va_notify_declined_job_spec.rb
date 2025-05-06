# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::VANotifyDeclinedJob, type: :job do
  subject { described_class.new }

  let(:va_notify_key) { ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController::VA_NOTIFY_KEY.to_s }
  let(:lockbox) { Lockbox.new(key: Settings.lockbox.master_key) }

  context 'when the representative is a service organization' do
    let(:vanotify_service) { instance_double(VaNotify::Service) }
    let(:ptcpnt_id) { '123456789' }
    let(:first_name) { 'Jane' }
    let(:encrypted_ptcpnt_id) { Base64.strict_encode64(lockbox.encrypt(ptcpnt_id)) }
    let(:encrypted_first_name) { Base64.strict_encode64(lockbox.encrypt(first_name)) }
    let(:representative_id) { '123' }

    before do
      allow(VaNotify::Service).to receive(:new).with(anything).and_return(vanotify_service)
      create(:veteran_representative, representative_id:, user_types: ['veteran_service_officer'])
    end

    it 'sends a declined service organization notification' do
      expect(vanotify_service).to receive(:send_email)
        .with({
                recipient_identifier: {
                  id_type: 'PID',
                  id_value: ptcpnt_id
                },
                personalisation: {
                  first_name:,
                  form_type: 'Appointment of Veterans Service Organization as Claimantʼs Representative (VA Form 21-22)'
                },
                template_id: Settings.claims_api.vanotify.declined_service_organization_template_id
              })

      subject.perform(encrypted_ptcpnt_id, encrypted_first_name, representative_id)
    end
  end

  context 'when the representative is an individual' do
    let(:vanotify_service) { instance_double(VaNotify::Service) }
    let(:ptcpnt_id) { '123456789' }
    let(:first_name) { 'Jane' }
    let(:encrypted_ptcpnt_id) { Base64.strict_encode64(lockbox.encrypt(ptcpnt_id)) }
    let(:encrypted_first_name) { Base64.strict_encode64(lockbox.encrypt(first_name)) }
    let(:representative_id) { '456' }

    before do
      allow(VaNotify::Service).to receive(:new).with(anything).and_return(vanotify_service)
      create(:veteran_representative, representative_id:, user_types: ['claim_agents'])
    end

    it 'sends a declined individual/representative notification' do
      expect(vanotify_service).to receive(:send_email)
        .with({
                recipient_identifier: {
                  id_type: 'PID',
                  id_value: ptcpnt_id
                },
                personalisation: {
                  first_name:,
                  representative_type: 'claims agent',
                  representative_type_abbreviated: 'claims agent',
                  form_type: 'Appointment of Individual as Claimantʼs Representative (VA Form 21-22a)'
                },
                template_id: Settings.claims_api.vanotify.declined_service_organization_template_id
              })

      subject.perform(encrypted_ptcpnt_id, encrypted_first_name, representative_id)
    end
  end
end
