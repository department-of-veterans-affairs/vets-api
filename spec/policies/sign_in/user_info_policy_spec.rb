# frozen_string_literal: true

require 'rails_helper'

describe SignIn::UserInfoPolicy do
  subject { described_class }

  let(:user) { build(:user) }
  let(:access_token) { build(:access_token, client_id:) }
  let(:client_id) { 'some-client-id' }
  let(:user_info_clients) { [client_id] }

  before do
    allow(IdentitySettings.sign_in).to receive(:user_info_clients).and_return(user_info_clients)
  end

  permissions :show? do
    context 'when the current_user is present' do
      let(:user) { build(:user) }

      context 'when the client_id is in the list of valid clients' do
        it 'grants access' do
          expect(subject).to permit(user, access_token)
        end
      end

      context 'when the client_id is not in the list of valid clients' do
        let(:user_info_clients) { ['some-other-client-id'] }

        it 'denies access' do
          expect(subject).not_to permit(user, access_token)
        end
      end
    end

    context 'when the current_user is not present' do
      let(:user) { nil }

      it 'denies access' do
        expect(subject).not_to permit(user, access_token)
      end
    end
  end
end
