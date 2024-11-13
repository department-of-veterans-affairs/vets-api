# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::VANotifyDeclinedJob, type: :job do
  subject { described_class.new }

  let(:va_notify_key) { ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController::VA_NOTIFY_KEY.to_s }

  context 'when the poa is a service organization' do
    let(:vanotify_service) { instance_double(VaNotify::Service) }
    let(:poa) do
      create(:power_of_attorney,
             form_data: { serviceOrganization: 'some organization' },
             auth_headers: {
               'va_eauth_firstName' => 'Jane',
               va_notify_key => '1234567890'
             })
    end

    before do
      allow(VaNotify::Service).to receive(:new).with(anything).and_return(vanotify_service)
    end

    it 'sends a declined service organization notification' do
      expect(vanotify_service).to receive(:send_email)
        .with({
                recipient_identifier: poa.auth_headers[va_notify_key],
                personalisation: {
                  first_name: poa.auth_headers['va_eauth_firstName'],
                  form_type: 'Appointment of Veterans Service Organization as Claimantʼs Representative (VA Form 21-22)'
                },
                template_id: Settings.claims_api.vanotify.declined_service_organization_template_id
              })

      subject.perform(poa.id)
    end
  end

  context 'when the poa is an individual/representative' do
    let(:vanotify_service) { instance_double(VaNotify::Service) }
    let(:poa) do
      create(:power_of_attorney,
             form_data: { representative: { type: 'attorney' } },
             auth_headers: {
               'va_eauth_firstName' => 'Jane',
               va_notify_key => '1234567890'
             })
    end

    before do
      allow(VaNotify::Service).to receive(:new).with(anything).and_return(vanotify_service)
    end

    it 'sends a declined individual/representative notification' do
      expect(vanotify_service).to receive(:send_email)
        .with({
                recipient_identifier: poa.auth_headers[va_notify_key],
                personalisation: {
                  first_name: poa.auth_headers['va_eauth_firstName'],
                  representative_type: 'attorney',
                  representative_type_abbreviated: 'attorney',
                  form_type: 'Appointment of Individual as Claimantʼs Representative (VA Form 21-22a)'
                },
                template_id: Settings.claims_api.vanotify.declined_service_organization_template_id
              })

      subject.perform(poa.id)
    end
  end
end
