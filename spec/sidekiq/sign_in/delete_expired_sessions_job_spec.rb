# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::DeleteExpiredSessionsJob do
  let!(:expired_oauth_session) { create(:oauth_session, refresh_expiration: 3.days.ago) }
  let!(:active_oauth_session) { create(:oauth_session, refresh_expiration: 3.days.from_now) }

  describe '#perform' do
    let(:job) { SignIn::DeleteExpiredSessionsJob.new }

    it 'deletes expired oauth sessions' do
      expect { job.perform }.to change(SignIn::OAuthSession, :count).by(-1)
    end

    it 'does not delete active oauth sessions' do
      expect { job.perform }.not_to change(active_oauth_session, :reload)
    end
  end
end
