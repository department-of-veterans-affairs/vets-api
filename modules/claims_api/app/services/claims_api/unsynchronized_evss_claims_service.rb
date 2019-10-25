# frozen_string_literal: true

require 'evss/claims_service'
require 'evss/documents_service'
require 'evss/auth_headers'

module ClaimsApi
  class UnsynchronizedEVSSClaimService
    include SentryLogging
    EVSS_CLAIM_KEYS = %w[open_claims historical_claims].freeze
    delegate :power_of_attorney, to: :veteran

    def initialize(user)
      @user = user
    end

    def all
      raw_claims = client.all_claims.body
      EVSS_CLAIM_KEYS.each_with_object([]) do |key, claim_accum|
        next unless raw_claims[key]

        claim_accum << raw_claims[key].map do |raw_claim|
          create_claim(raw_claim['id'], :list_data, raw_claim)
        end
      end.flatten
    end

    def count
      raw_claims = client.all_claims.body
      EVSS_CLAIM_KEYS.each_with_object([]) do |key, claim_accum|
        next unless raw_claims[key]

        claim_accum << raw_claims[key].map do |raw_claim|
          raw_claim['id']
        end
      end.flatten.count
    end

    def update_from_remote(evss_id)
      raw_claim = client.find_claim_by_id(evss_id).body.fetch('claim', {})
      create_claim(evss_id, :data, raw_claim)
    end

    def veteran
      return @veteran if defined? @veteran

      @veteran = ::Veteran::User.new(@user)
    end

    private

    def client
      @client ||= EVSS::ClaimsService.new(auth_headers)
    end

    def auth_headers
      @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
    end

    def claims_scope
      EVSSClaim.for_user(@user)
    end

    def create_claim(evss_id, key, raw_claim)
      ClaimsApi::EVSSClaim.new(:evss_id => evss_id, key => raw_claim)
    end
  end
end
