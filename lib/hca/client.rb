# frozen_string_literal: true
require 'common/client/base'
require 'hca/configuration'

module HCA
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration HCA::Configuration

    # add your methods here
=begin
    def post_hca(json_body)
      response = perform(:post, 'url_partial', json_body, {})
    end
=end
  end
end
