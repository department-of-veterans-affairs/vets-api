# frozen_string_literal: true

require 'rails_helper'
require 'apps_api/notification_service'

describe AppsApi::NotificationService do
  subject { AppsApi::NotificationService.new }

  describe '#initialize' do
    it 'initializes the class correctly' do
      expect(subject.instance_variable_get(:@okta_service)).to be_instance_of(Okta::Service)
      expect(subject.instance_variable_get(:@notify_client)).to be_instance_of(VaNotify::Service)
      expect(subject.instance_variable_get(:@connection_event)).to be('app.oauth2.as.consent.grant')
      expect(subject.instance_variable_get(:@disconnection_event)).to be('app.oauth2.as.token.revoke')
    end
  end

  describe 'get_events' do
    it 'returns a response body of connections' do
      VCR.use_cassette('okta/connection_logs', match_requests_on: %i[method path]) do
        # to ensure our vcr has data in the response
        # set timecop for time in vcr 2020-12-23T19:47:05Z
        subject.instance_variable_set(:@time_period, 5.days.ago.utc.iso8601)
        response = subject.get_events('app.oauth2.as.consent.grant')
        expect(response.body).not_to be_empty
      end
    end
    it 'returns a response body of disconnections' do
      VCR.use_cassette('okta/disconnection_logs', match_requests_on: %i[method]) do
        # to ensure our vcr has data in the response
        subject.instance_variable_set(:@time_period, 5.days.ago.utc.iso8601)
        response = subject.get_events('app.oauth2.as.token.revoke')
        expect(response.body).not_to be_empty
      end
    end
  end

  describe 'when validating events' do
    context 'and the event is a connection' do
      let(:invalid_connection_event) do
        {
          'actor' => {
            'id' => '1234',
            'type' => 'User',
            'alternateId' => '',
            'displayName' => 'John Doe',
            'detailEntry' => nil
          },
          'client' => {},
          'authenticationContext' => {},
          'displayMessage' => 'Consent granted',
          'eventType' => 'app.oauth2.as.consent.grant',
          'outcome' => {
            'result' => 'FAILED',
            'reason' => ''
          },

          'published' => '2020-10-01T17:37:49.538Z',
          'securityContext' => {},
          'severity' => 'INFO',
          'debugContext' => {},
          'legacyEventType' => 'app.oauth2.as.consent.grant_success',
          'transaction' => {},
          'uuid' => '{event_id}',
          'version' => '0',
          'request' => {},
          'target' => [
            {
              'id' => 'oagke4gvwYHTncxlI2p6',
              'type' => 'ConsentGrant',
              'alternateId' => nil,
              'displayName' => 'veteran_status.read',
              'detailEntry' => {
                'publicclientapp' => '{app_id}',
                'authorizationserver' => '{auth_server_id}',
                'user' => '{user_id}'
              }
            }
          ]
        }
      end

      let(:valid_connection_event) do
        {
          'actor' => {
            'id' => '1234',
            'type' => 'User',
            'alternateId' => '',
            'displayName' => 'John Doe',
            'detailEntry' => nil
          },
          'client' => {},
          'authenticationContext' => {},
          'displayMessage' => 'Consent granted',
          'eventType' => 'app.oauth2.as.consent.grant',
          'outcome' => {
            'result' => 'SUCCESS',
            'reason' => ''
          },

          'published' => '2020-10-01T17:37:49.538Z',
          'securityContext' => {},
          'severity' => 'INFO',
          'debugContext' => {},
          'legacyEventType' => 'app.oauth2.as.consent.grant_success',
          'transaction' => {},
          'uuid' => '{event_id}',
          'version' => '0',
          'request' => {},
          'target' => [
            {
              'id' => 'oagke4gvwYHTncxlI2p6',
              'type' => 'ConsentGrant',
              'alternateId' => nil,
              'displayName' => 'veteran_status.read',
              'detailEntry' => {
                'publicclientapp' => '{app_id}',
                'authorizationserver' => '{auth_server_id}',
                'user' => '{user_id}'
              }
            }
          ]
        }
      end

      let(:invalid_disconnection_event) do
        {
          'actor' => {
            'id' => '{app_id}',
            'type' => 'PublicClientApp',
            'alternateId' => '',
            'displayName' => 'LibertyITCrochet-2020-05-18T14=>48=>22.744Z',
            'detailEntry' => nil
          },
          'client' => {},
          'authenticationContext' => {},
          'displayMessage' => 'OAuth2 token revocation request',
          'eventType' => 'app.oauth2.as.token.revoke',
          'outcome' => {
            'result' => 'SUCCESS',
            'reason' => nil
          },
          'published' => '2020-10-08T18=>08=>41.204Z',
          'securityContext' => {},
          'severity' => 'INFO',
          'debugContext' => {},
          'legacyEventType' => 'app.oauth2.as.token.revoke_success',
          'transaction' => {},
          'uuid' => 'XXYYZZ',
          'version' => '0',
          'request' => {},
          'target' => [
            {
              'id' => '{token_id}',
              'type' => 'access_token',
              'alternateId' => nil,
              'displayName' => 'Access Token',
              'detailEntry' => {
                'expires' => '2020-10-08T19:04:32.000Z',
                'subject' => nil,
                'hash' => ''
              }
            }
          ]
        }
      end

      let(:valid_disconnection_event) do
        {
          'actor' => {
            'id' => '{app_id}',
            'type' => 'PublicClientApp',
            'alternateId' => '',
            'displayName' => 'LibertyITCrochet-2020-05-18T14=>48=>22.744Z',
            'detailEntry' => nil
          },
          'client' => {},
          'authenticationContext' => {},
          'displayMessage' => 'OAuth2 token revocation request',
          'eventType' => 'app.oauth2.as.token.revoke',
          'outcome' => {
            'result' => 'SUCCESS',
            'reason' => nil
          },
          'published' => '2020-10-08T18=>08=>41.204Z',
          'securityContext' => {},
          'severity' => 'INFO',
          'debugContext' => {},
          'legacyEventType' => 'app.oauth2.as.token.revoke_success',
          'transaction' => {},
          'uuid' => 'XXYYZZ',
          'version' => '0',
          'request' => {},
          'target' => [
            {
              'id' => '{token_id}',
              'type' => 'access_token',
              'alternateId' => nil,
              'displayName' => 'Access Token',
              'detailEntry' => {
                'expires' => '2020-10-08T19:04:32.000Z',
                'subject' => 'this one has a subject!',
                'hash' => ''
              }
            }
          ]
        }
      end

      it 'does not validate invalid connection events' do
        expect(subject.event_is_invalid(invalid_connection_event)).to be(true)
      end

      it 'validates valid connection events' do
        expect(subject.event_is_invalid(valid_connection_event)).to be(false)
      end

      it 'does not validate invalid disconnection events' do
        expect(subject.event_is_invalid(invalid_disconnection_event)).to be(true)
      end

      it 'validates valid disconnection events' do
        expect(subject.event_is_invalid(valid_disconnection_event)).to be(false)
      end
    end
  end
end
