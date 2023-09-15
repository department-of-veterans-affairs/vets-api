# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::SignUpServiceUpdaterJob, type: :job do
  describe '#perform' do
    let(:user_account) { create(:user_account) }
    let(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:, response:) }
    let(:job) { described_class.new }
    let(:response) { 'accepted' }
    let(:common_name) { 'some-common-name' }
    let(:service_instance) { instance_double(MobileApplicationPlatform::SignUp::Service) }
    let(:version) { terms_of_use_agreement.agreement_version }

    before do
      allow(MobileApplicationPlatform::SignUp::Service).to receive(:new).and_return(service_instance)
    end

    context 'when the terms of use agreement is accepted' do
      before do
        allow(service_instance).to receive(:agreements_accept)
      end

      it 'updates the terms of use agreement in sign up service' do
        job.perform(terms_of_use_agreement.id, common_name)

        expect(MobileApplicationPlatform::SignUp::Service).to have_received(:new)
        expect(service_instance).to have_received(:agreements_accept).with(icn: user_account.icn,
                                                                           signature_name: common_name,
                                                                           version:)
      end
    end

    context 'when the terms of use agreement is declined' do
      let(:response) { 'declined' }

      before do
        allow(service_instance).to receive(:agreements_decline)
      end

      it 'updates the terms of use agreement in sign up service' do
        job.perform(terms_of_use_agreement.id, common_name)

        expect(MobileApplicationPlatform::SignUp::Service).to have_received(:new)
        expect(service_instance).to have_received(:agreements_decline).with(icn: user_account.icn)
      end
    end
  end
end
