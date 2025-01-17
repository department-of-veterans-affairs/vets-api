# frozen_string_literal: true

require 'audit_logger/storage/base_adapter'
require 'mongo'

module AuditLogger
  module Storage
    class MongoAdapter < BaseAdapter
      attr_accessor :host, :user, :password, :database, :collection

      def initialize(host: 'localhost:27017', user: nil, password: nil, database: 'audit', collection: 'logs')
        super()

        @host = host
        @user = user
        @password = password
        @database = database
        @collection = collection

        setup
      end

      def client
        @client ||= ::Mongo::Client.new([host], user:, password:, database:)
      end

      def write(log)
        client[collection].insert_one(log)
      end

      def read(query)
        client[collection].find(query)
      end

      def validate!
        missing_args = []

        missing_args << 'host' if host.nil?
        missing_args << 'database' if database.nil?
        missing_args << 'collection' if collection.nil?

        raise ArgumentError, "Missing required fields: #{missing_args.join(', ')}" if missing_args.any?
      end

      private

      def setup
        Mongo::Logger.logger = Logger.new('log/mongo.log')
        Mongo::Logger.logger.level = Logger::INFO
      end
    end
  end
end
