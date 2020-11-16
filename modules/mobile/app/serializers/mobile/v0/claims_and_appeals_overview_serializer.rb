# frozen_string_literal: true

require 'ostruct'

module Mobile
  module V0
    class ClaimsAndAppealsOverviewSerializer
      include FastJsonapi::ObjectSerializer

      set_type :claimsAndAppealsOverview
      attributes :claims_and_appeals, :upstream_service_errors

      def initialize(id, claims, appeals, options = {})
        formatted_entries = []
        upstream_service_errors = []
        serialize_claims(claims, formatted_entries, upstream_service_errors)
        serialize_appeals(appeals, formatted_entries, upstream_service_errors)
        formatted_entries = formatted_entries.sort_by { |entry| entry[:attributes][:date_filed] }.reverse!
        resource = OverviewStruct.new(id, formatted_entries, upstream_service_errors)
        super(resource, options)
      end

      def serialize_claims(claims, formatted_entries, service_errors)
        if defined?(claims.body)
          format_errors(service_errors, 'claims', claims.body['messages'])
        else
          claims.each do |claim|
            formatted_claim = Mobile::V0::ClaimOverviewSerializer.new(claim).to_hash
            formatted_entries.push(formatted_claim[:data])
          end
        end
      end

      def serialize_appeals(appeals, formatted_entries, service_errors)
        if defined?(appeals.errors)
          format_errors(service_errors, 'appeals', appeals.errors)
        else
          appeals.each do |appeal|
            if appeal['type'].downcase.include? 'appeal' # Filtering out HLR and Supp Claims
              formatted_appeal = Mobile::V0::AppealOverviewSerializer.new(appeal).to_hash
              formatted_entries.push(formatted_appeal[:data])
            end
          end
        end
      end

      def format_errors(service_errors, upstream_service, debug_messages)
        error = OpenStruct.new
        error.upstream_service = upstream_service
        error.debug_messages = debug_messages
        service_errors.push(error.to_h)
      end
    end

    OverviewStruct = Struct.new(:id, :claims_and_appeals, :upstream_service_errors)
  end
end
