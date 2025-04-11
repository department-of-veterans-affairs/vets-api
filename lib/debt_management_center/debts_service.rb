# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debt_management_center/debts_configuration'
require 'debt_management_center/responses/debts_response'

module DebtManagementCenter
  class DebtsService < DebtManagementCenter::BaseService
    include RedisCaching
    attr_reader :file_number

    class DebtNotFound < StandardError; end
    configuration DebtManagementCenter::DebtsConfiguration

    STATSD_KEY_PREFIX = 'api.dmc'

    def initialize(user)
      super(user)
      @debts = nil
    end

    def get_debts(count_only: false)
      # @param count_only [Boolean]
      # When true, returns only { "debtsCount" => Integer }
      # When false, returns full debt details with histories
      if count_only
        with_monitoring_and_error_handling do
          response = fetch_debts_from_dmc(count_only: true)
          StatsD.increment("#{STATSD_KEY_PREFIX}.get_debts_count.success")
          return response
        end
      end

      load_debts unless @debts

      has_dependent_debts = veteran_has_dependent_debts?
      debts = debts_with_sorted_histories
      StatsD.increment("#{STATSD_KEY_PREFIX}.get_debts.success")
      {
        has_dependent_debts:,
        debts:
      }
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.get_debts.failure")
      raise e
    end

    def get_debt_by_id(id)
      load_debts unless @debts

      debt_store = DebtManagementCenter::DebtStore.find(@user.uuid)

      raise DebtNotFound if debt_store.blank?

      debt = debt_store.get_debt(id)
      StatsD.increment("#{STATSD_KEY_PREFIX}.get_debt.success")
      debt
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.get_debt.failure")
      raise e
    end

    def veteran_has_dependent_debts?
      load_debts unless @debts
      @debts.any? { |debt| debt['payeeNumber'] != '00' }
    end

    private

    def debts_with_sorted_histories
      @debts.select do |debt|
        debt['debtHistory'] = sort_by_date(debt['debtHistory'])
        debt['compositeDebtId'] = build_composite_debt_id(debt)
        debt['payeeNumber'] == '00'
      end
    end

    def build_composite_debt_id(debt)
      "#{debt['deductionCode']}#{debt['originalAR'].to_i}"
    end

    def load_debts
      @debts = init_cached_debts
    end

    def init_cached_debts
      StatsD.increment("#{STATSD_KEY_PREFIX}.init_cached_debts.fired")

      cache_key = "debts_data_#{@user.uuid}"
      cached_response = Rails.cache.read(cache_key)

      if cached_response
        StatsD.increment("#{STATSD_KEY_PREFIX}.init_cached_debts.cached_response_returned")
        return DebtManagementCenter::DebtsResponse.new(cached_response).debts
      end

      response = fetch_debts_from_dmc

      if response.is_a?(Array) && response.empty?
        # DMC refreshes DB at 5am every morning
        Rails.cache.write(cache_key, response, expires_in: self.class.time_until_5am_utc)
        StatsD.increment("#{STATSD_KEY_PREFIX}.init_cached_debts.empty_response_cached")
      end

      response
    end

    def fetch_debts_from_dmc(count_only: false)
      with_monitoring_and_error_handling do
        options = { timeout: 30 }
        payload = { fileNumber: @file_number }
        payload[:countOnly] = true if count_only

        response = perform(:post, Settings.dmc.debts_endpoint, payload, nil, options).body

        return extract_debts_count(response) if count_only

        DebtManagementCenter::DebtsResponse.new(response).debts
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.fetch_debts_from_dmc.fail", tags: [
                           "error:#{e.class.name}",
                           "status:#{e.respond_to?(:status) ? e.status : 'unknown'}"
                         ])
        raise e
      end
    end

    def extract_debts_count(response)
      # If response is the desired format, return it.
      # If it is an array, return just the count.
      # Sometimes we get back the default mocked file, then we count and return that.

      return response if response.is_a?(Hash) && response.key?('debtsCount')

      return response.first if response.is_a?(Array) && response.first.is_a?(Hash) && response.first.key?('debtsCount')

      if response.is_a?(Array) && response.any? { |debt| debt['fileNumber'].present? }
        return { 'debtsCount' => response.length }
      end

      response
    end

    def sort_by_date(debt_history)
      debt_history.sort_by { |d| Date.strptime(d['date'], '%m/%d/%Y') }.reverse
    end
  end
end
