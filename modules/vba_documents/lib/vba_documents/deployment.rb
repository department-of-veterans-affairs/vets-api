# frozen_string_literal: true

module VBADocuments
  module Deployment
    class << self
      send(:attr_accessor, :environment)
    end

    def self.fetch_environment
      prefix = Settings.vba_documents.location.prefix
      prefix =~ /https:.*?-(dev|staging|sandbox|prod)-.*/
      begin
        Regexp.last_match(1).to_sym
      rescue
        :unknown_environment
      end
    end
    VBADocuments::Deployment.environment = VBADocuments::Deployment.fetch_environment
  end
end
