# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'

RSpec.describe MHV::AuditLogoutJob do
  let(:mhv_correlation_id) { '12345' }
  let(:signed_in_time) { Time.current }
  let(:user_uuid) { SecureRandom.uuid }
  let(:user_identity) { instance_double(UserIdentity, uuid: user_uuid, mhv_correlation_id: mhv_correlation_id) }
  let(:mhv_user) { instance_double(User, uuid: user_uuid, mhv_correlation_id: mhv_correlation_id, mhv_last_signed_in: signed_in_time) }
  
  let(:authenticated_client) do
    MHVLogging::Client.new(session: { user_id: mhv_correlation_id,
                                     expires_at: Time.current + (60 * 60),
                                     token: '<SESSION_TOKEN>' })
  end

  before do
    allow(MHVLogging::Client).to receive(:new).and_return(authenticated_client)
    allow(authenticated_client).to receive_message_chain(:authenticate, :auditlogout)
    allow(User).to receive(:find).with(user_uuid).and_return(mhv_user)
    allow(mhv_user).to receive(:save)
  end

  describe 'perform' do
    it 'audits an MHV logout for a user with mhv_last_signed_in' do
      allow(UserIdentity).to receive(:where).with(mhv_correlation_id: mhv_correlation_id).and_return([user_identity])
      
      described_class.new.perform(mhv_correlation_id, signed_in_time.iso8601)

      expect(authenticated_client).to have_received(:authenticate)
      expect(mhv_user).to have_received(:save)
    end

    it 'does not audit logout if mhv_last_signed_in is nil' do
      described_class.new.perform(mhv_correlation_id, nil)

      expect(authenticated_client).not_to have_received(:authenticate)
    end

    it 'does not audit logout if mhv_correlation_id is blank' do
      described_class.new.perform(nil, signed_in_time.iso8601)

      expect(authenticated_client).not_to have_received(:authenticate)
    end

    context 'with multiple users having the same MHV correlation ID' do
      let(:delegate_uuid) { SecureRandom.uuid }
      let(:delegate_identity) { instance_double(UserIdentity, uuid: delegate_uuid, mhv_correlation_id: mhv_correlation_id) }
      let(:delegate_user) { instance_double(User, uuid: delegate_uuid, mhv_correlation_id: mhv_correlation_id, mhv_last_signed_in: signed_in_time) }

      before do
        allow(UserIdentity).to receive(:where).with(mhv_correlation_id: mhv_correlation_id).and_return([user_identity, delegate_identity])
        allow(User).to receive(:find).with(delegate_uuid).and_return(delegate_user)
        allow(delegate_user).to receive(:save)
      end

      it 'updates all users with the same MHV correlation ID' do
        described_class.new.perform(mhv_correlation_id, signed_in_time.iso8601)

        expect(mhv_user).to have_received(:save)
        expect(delegate_user).to have_received(:save)
      end
    end
    
    context 'with user_account_id provided' do
      let(:user_verification) { instance_double(UserVerification, user_account_id: 1, user_uuid: user_uuid) }
      let(:user_account) { instance_double(UserAccount, id: 1, user_verifications: [user_verification]) }
      let(:user_with_account) { instance_double(User, uuid: user_uuid, mhv_correlation_id: mhv_correlation_id, mhv_last_signed_in: signed_in_time) }
      let(:other_identity) { instance_double(UserIdentity, uuid: 'other-uuid', mhv_correlation_id: mhv_correlation_id) }
      let(:other_user) { instance_double(User, uuid: 'other-uuid', mhv_correlation_id: mhv_correlation_id, mhv_last_signed_in: signed_in_time) }

      before do
        allow(UserAccount).to receive(:find_by).with(id: 1).and_return(user_account)
        allow(User).to receive(:find).with(user_uuid).and_return(user_with_account)
        allow(user_with_account).to receive(:save)
        
        # Don't expect calls to these in this case
        allow(UserIdentity).to receive(:where).with(mhv_correlation_id: mhv_correlation_id).and_return([user_identity, other_identity])
        allow(User).to receive(:find).with('other-uuid').and_return(other_user)
        allow(other_user).to receive(:save)
      end

      it 'updates only the user associated with the account' do
        described_class.new.perform(mhv_correlation_id, signed_in_time.iso8601, 1)

        expect(user_with_account).to have_received(:save)
        expect(other_user).not_to have_received(:save)
      end
    end
  end
end 
