# frozen_string_literal: true

require 'faraday'

namespace :test_526 do

  desc 'test submit endpoint'
  task :submit, [:times_to_run, :env] do |_, args|

    case args[:env]
    when 'staging'
      user_token = 'ryqdYQV2eVELu7xHYeUc6YSaH5k9wx9rnhsdG1DM'
      post_itf(user_token,args[:env])
    when 'dev'
      user_token = 'sDjLs5v9sqjQHx7o5Gxr7ZvSQKz5as25UC9EwK_W'
      post_itf(user_token,args[:env])
    end
  end
end

def post_itf(user_token,env)

  conn = Faraday.new(:url => "https://staging-api.vets.gov") do |faraday|
    faraday.response :json, content_type: /\bjson$/
    faraday.adapter Faraday.default_adapter
  end

  response = conn.post do |req|
    req.url '/v0/intent_to_file/compensation'
    req.headers['Authorization'] = "Token token=#{user_token}"
  end

  puts response.status
  puts response.body
end
