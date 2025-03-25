# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'

RSpec.describe MHV::AuditLogoutJob do
  let(:mhv_correlation_id) { '12345' }
  let(:signed_in_time) { Time.current }
  let(:user_uuid) { SecureRandom.uuid }
  let(:mhv_user) do
    instance_double(User, uuid: user_uuid, mhv_correlation_id:, mhv_last_signed_in: signed_in_time)
  end

  let(:authenticated_client) do
    MHVLogging::Client.new(session: { user_id: mhv_correlation_id,
                                      expires_at: Time.current + (60 * 60),
                                      token: '<SESSION_TOKEN>' })
  end

  before do
    # Set up authenticated client stubbing
    allow(MHVLogging::Client).to receive(:new).and_return(authenticated_client)

    # Create a double for the authenticate method
    auth_object = double('authenticate')
    allow(authenticated_client).to receive(:authenticate).and_return(auth_object)
    allow(auth_object).to receive(:auditlogout)
  end

  describe 'perform' do
    describe 'early returns' do
      it 'does not audit logout if mhv_last_signed_in is nil' do
        described_class.new.perform(mhv_correlation_id, nil)
        expect(authenticated_client).not_to have_received(:authenticate)
      end

      it 'does not audit logout if mhv_correlation_id is blank' do
        described_class.new.perform(nil, signed_in_time.iso8601)
        expect(authenticated_client).not_to have_received(:authenticate)
      end
    end

    describe 'user account path', skip: 'Implementation pending - will be revisited when PR is fully implemented' do
      # These tests will be implemented when the PR is being fully implemented
      it 'calls the MHV audit client'
      it 'updates the user via the account path'
    end
  end
end
