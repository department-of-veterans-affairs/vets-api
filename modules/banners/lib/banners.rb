# frozen_string_literal: true

require 'banners/engine'

module Banners
  # Here is where I will fetch the banner data from graphql and update the banner table
  # ensuring old banners are upadated or removed and new banners are added
  # 
  # this example from form_reloader.rb is a good example of how to do the fetch

  # def all_forms_data
  #   query = File.read(Rails.root.join('modules', 'va_forms', 'config', 'graphql_query.txt'))
  #   body = { query: }
  #   response = connection.post do |req|
  #     req.path = 'graphql'
  #     req.body = body.to_json
  #     req.options.timeout = 300
  #   end
  #   JSON.parse(response.body).dig('data', 'nodeQuery', 'entities')
  # end
end
