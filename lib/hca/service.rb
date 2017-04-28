# frozen_string_literal: true
require 'common/client/base'

module HCA
  class Service < Common::Client::Base
    def initialize(current_user = nil)
      @current_user = current_user
    end

    private

    def post_submission(submission)
      perform(:post, '', submission.body)
    end

    def soap(namespace:, service_namespace:)
      # Savon *seems* like it should be setting these things correctly
      # from what the docs say. Our WSDL file is weird, maybe?
      Savon.client(wsdl: config.class::WSDL,
                   endpoint: config.base_path,
                   env_namespace: :soap,
                   element_form_default: :qualified,
                   namespaces: {
                     'xmlns:tns': service_namespace
                   },
                   namespace: namespace)
    end
  end
end
