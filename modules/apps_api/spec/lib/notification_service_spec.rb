# frozen_string_literal: true
require 'rails_helper'
require 'apps_api/notification_service'

describe AppsApi::NotificationService do
  subject {descibed_class.new}

  describe 'handle_connect' do
    VCR.use_cassette('okta/connection_logs') do

    end
  end

  describe 'handle_disconnect' do
    VCR.use_cassette('okta/disconnection_logs') do

    end
  end

  describe 'get_events' do
  end
end
