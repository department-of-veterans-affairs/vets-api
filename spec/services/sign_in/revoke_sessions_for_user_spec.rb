# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::RevokeSessionsForUser do
  describe '#perform' do
    subject { SignIn::RevokeSessionsForUser.new(user_account:).perform }

    let(:user_account) { create(:user_account) }
    let!(:oauth_session_1) { create(:oauth_session, user_account:) }
    let!(:oauth_session_2) { create(:oauth_session, user_account:) }
    let(:oauth_session_count) { SignIn::OauthSession.where(user_account:).count }

    it 'deletes all sessions associated with given user account' do
      expect { subject }.to change(SignIn::OauthSession, :count).from(oauth_session_count).to(0)
    end
  end
end
