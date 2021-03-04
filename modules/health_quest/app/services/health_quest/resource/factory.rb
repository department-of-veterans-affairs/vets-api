# frozen_string_literal: true

module HealthQuest
  module Resource
    class Factory
      attr_reader :session_service, :user, :query, :resource_identifier, :options_builder

      def self.manufacture(opts = {})
        new(opts)
      end

      def initialize(opts)
        @user = opts[:user]
        @resource_identifier = opts[:resource_identifier]
        @session_service = HealthQuest::Lighthouse::Session.build(user: user, api: opts[:api])
        @query = Query.build(session_store: session_service.retrieve,
                             api: opts[:api],
                             resource_identifier: resource_identifier)
        @options_builder = Shared::OptionsBuilder
      end

      def get(id) # rubocop:disable Rails/Delegate
        query.get(id)
      end

      def search(filters = {})
        filters.merge!(resource_name)

        with_options = options_builder.manufacture(user, filters).to_hash
        query.search(with_options)
      end

      def create(data)
        query.create(data, user)
      end

      def resource_name
        { resource_name: resource_identifier }
      end
    end
  end
end
