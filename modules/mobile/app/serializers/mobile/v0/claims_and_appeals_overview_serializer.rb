# frozen_string_literal: true

module Mobile
  module V0
    class ClaimsAndAppealsOverviewSerializer
      include FastJsonapi::ObjectSerializer

      set_type :claimsAndAppealsOverview
      attributes :claims_and_appeals

      def initialize(id, claims, appeals, options = {})
        formatted_entries = []
        claims.each do |claim|
          formatted_claim = Mobile::V0::ClaimOverviewSerializer.new(claim).to_hash
          formatted_entries.push(formatted_claim[:data])
        end

        appeals.each do |appeal|
          if appeal['type'].downcase.include? 'appeal' # Filtering out HLR and Supp Claims
            formatted_appeal = Mobile::V0::AppealOverviewSerializer.new(appeal).to_hash
            formatted_entries.push(formatted_appeal[:data])
          end
        end
        formatted_entries = formatted_entries.sort_by { |entry| entry[:attributes][:date_filed] }.reverse!
        resource = OverviewStruct.new(id, formatted_entries)
        super(resource, options)
      end
    end

    OverviewStruct = Struct.new(:id, :claims_and_appeals)
  end
end
