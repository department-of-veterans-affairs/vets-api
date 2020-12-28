# frozen_string_literal: true

require 'rails_helper'
require 'apps_api/notification_service'

describe AppsApi::NotificationService do
  subject { AppsApi::NotificationService.new }

  describe 'get_events' do
    it 'returns a response body of connections' do
      VCR.use_cassette('okta/connection_logs', match_requests_on: %i[method host]) do
        # to ensure our vcr has data in the response
        subject.instance_variable_set(:@time_period, 5.days.ago.utc.iso8601)
        response = subject.get_events('app.oauth2.as.consent.grant')
        expect(response.body).not_to be_empty
      end
    end
    it 'returns a response body of disconnections' do
      VCR.use_cassette('okta/disconnection_logs', match_requests_on: %i[method host]) do
        # to ensure our vcr has data in the response
        subject.instance_variable_set(:@time_period, 5.days.ago.utc.iso8601)
        response = subject.get_events('app.oauth2.as.token.revoke')
        expect(response.body).not_to be_empty
      end
    end
  end
end
