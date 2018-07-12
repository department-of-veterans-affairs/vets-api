# frozen_string_literal: true

require_relative 'submit_form_data_generator'

class TestRunner
  def initialize(env, user_token)
    @user_token = user_token
    @conn = Faraday.new(url: "https://#{env}-api.vets.gov") do |faraday|
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter Faraday.default_adapter
    end
  end

  def active_itf?
    response = @conn.get do |req|
      req.url '/v0/intent_to_file/compensation/active'
      req.headers['Authorization'] = "Token token=#{@user_token}"
    end
    puts "\n\n--- GET ACTIVE ITF RESPONSE ---\n\n"
    puts response.status
    puts response.body

    response.body.dig('data', 'attributes', 'intent_to_file', 'status') == 'active'
  end

  def create_itf
    response = @conn.post do |req|
      req.url '/v0/intent_to_file/compensation'
      req.headers['Authorization'] = "Token token=#{@user_token}"
    end
    puts "\n\n--- CREATE ITF RESPONSE ---\n\n"
    puts response.status
    puts response.body
  end

  def submit
    response = @conn.post do |req|
      req.url '/v0/disability_compensation_form/submit'
      req.headers['Authorization'] = "Token token=#{@user_token}"
      form_data = SubmitFormDataGenerator.new
      puts "\nREQUEST BODY --- \n\n"
      pp form_data.to_hash
      req.body = form_data.to_json
    end
    puts "\n\n--- SUBMIT RESPONSE ---\n\n"
    puts "RESPONSE: #{response.status}"
    puts 'BODY:'
    puts response.body
  end

  def rated_disabilities
    response = @conn.get do |req|
      req.url '/v0/disability_compensation_form/rated_disabilities'
      req.headers['Authorization'] = "Token token=#{@user_token}"
    end
    puts "\n\n--- SUBMIT RESPONSE ---\n\n"
    puts "RESPONSE: #{response.status}"
    puts 'BODY:'
    puts response.body
  end
end
