# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'

RSpec.describe MHV::AuditLoginJob do
  let(:mhv_correlation_id) { '12345' }
  let(:user_uuid) { SecureRandom.uuid }
  let(:mhv_user) { instance_double(User, uuid: user_uuid, mhv_correlation_id: mhv_correlation_id, mhv_last_signed_in: nil) }
  let(:user_account) { instance_double(UserAccount, id: 1) }
  
  let(:authenticated_client) do
    MHVLogging::Client.new(session: { user_id: mhv_correlation_id,
                                     expires_at: Time.current + (60 * 60),
                                     token: '<SESSION_TOKEN>' })
  end

  before do
    allow(MHVLogging::Client).to receive(:new).and_return(authenticated_client)
    allow(authenticated_client).to receive_message_chain(:authenticate, :auditlogin)
  end

  describe 'perform' do
    describe 'early returns' do
      it 'does not audit login if mhv_last_signed_in is present' do
        described_class.new.perform(mhv_correlation_id, Time.current.iso8601)
        expect(authenticated_client).not_to have_received(:authenticate)
      end

      it 'does not audit login if mhv_correlation_id is blank' do
        described_class.new.perform(nil, nil)
        expect(authenticated_client).not_to have_received(:authenticate)
      end
    end

    describe 'user account path', skip: 'Implementation pending - will be revisited when PR is fully implemented' do
      it 'calls the MHV audit client'
      it 'updates the user via the account path'
    end
  end
end 
