# frozen_string_literal: true
require 'faraday'
require 'json'
require 'net/http'


class TimeOfNeedService

  def initialize
    header = {'Content-Type': 'application/x-www-form-urlencoded'}
    body = 'client_secret=' + Settings.time_of_need.client_secret.to_s +
        '&' + 'client_id=' + Settings.time_of_need.client_id +
        '&' + 'username=' + Settings.time_of_need.username +
        '&' + 'password=' + Settings.time_of_need.password +
        '&' + 'grant_type=' + Settings.time_of_need.grant_type
    http = Net::HTTP.new("va--MBMSSit.cs33.my.salesforce.com", 443)
    http.use_ssl = true
    request = Net::HTTP::Post.new(Settings.time_of_need.salesforce_url, header)
    request.body = body
    @response = http.request(request)
  end

  def create(ton)
    oauth_token = JSON.parse(@response.body)["access_token"]
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
