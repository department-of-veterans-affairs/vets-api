# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::CreateUserAccountJob, type: :job do
  subject { described_class.new.perform(user_uuid) }

  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:user_uuid) { user.uuid }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:client_stub) { instance_double('EVSS::CommonService') }

  before do
    allow(SecureRandom).to receive(:uuid).and_return('some-random-number')
    allow(EVSS::CommonService).to receive(:new).with(auth_headers) { client_stub }
  end

  context 'user redis exists' do
    let(:user) { FactoryBot.create(:user, :loa3) }

    it 'calls create_user_account EVSS API' do
      expect(client_stub).to receive(:create_user_account).once
      subject
    end
  end

  context 'user redis does not exist' do
    context 'and IAM User redis exists' do
      let(:user) { create(:iam_user) }

      it 'calls create_user_account EVSS API' do
        expect(client_stub).to receive(:create_user_account).once
        subject
      end
    end

    context 'and IAM user redis does not exist' do
      let(:user_uuid) { 'some-user-uuid' }

      it 'returns without calling EVSS' do
        expect(client_stub).not_to receive(:create_user_account)
        described_class.new.perform(user_uuid)
      end
    end
  end
end
