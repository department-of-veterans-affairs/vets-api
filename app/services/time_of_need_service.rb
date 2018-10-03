# frozen_string_literal: true
require 'faraday'
require 'json'
require 'net/http'

module TimeOfNeed
  class TimeOfNeedService < Common::Client::Base

    def initialize
      @conn = Faraday.new(:url => Settings.time_of_need.faraday_url)

      @request = @conn.post do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = 'client_secret=' + Settings.time_of_need.client_secret.to_s +
            '&' + 'client_id=' + Settings.time_of_need.client_id +
            '&' + 'username=' + Settings.time_of_need.username +
            '&' + 'password=' + Settings.time_of_need.password +
            '&' + 'grant_type=' + Settings.time_of_need.grant_type
      end
    end

    def create(ton)
      oauth_token = JSON.parse(@request.body)["access_token"]
      http = Net::HTTP.new(Settings.time_of_need.instance_url, 443)
      http.use_ssl = true
      request = Net::HTTP::Post.new("/services/apexrest/MBMS/Case", {'Content-Type' => 'application/json', 'Authorization' => 'OAuth '+oauth_token})
      request.body = ton.to_json

      response = http.request(request)
      response.body
    end

    def read(id)
      @client.find('Case', id)
    end

  end
end