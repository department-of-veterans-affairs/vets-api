# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debt_management_center/debts_configuration'
require 'debt_management_center/responses/debts_response'

module DebtManagementCenter
  class DebtsService < DebtManagementCenter::BaseService
    attr_reader :file_number

    class DebtNotFound < StandardError; end
    configuration DebtManagementCenter::DebtsConfiguration

    STATSD_KEY_PREFIX = 'api.dmc'

    def initialize(user)
      super(user)
      @debts = if Flipper.enabled?(:debts_cache_dmc_empty_response)
                 init_cached_debts
               else
                 init_debts
               end
    end

    def get_debts
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
      @debts.any? { |debt| debt['payeeNumber'] != '00' }
    end

    private

    def debts_with_sorted_histories
      @debts.select do |debt|
        debt['debtHistory'] = sort_by_date(debt['debtHistory'])
        debt['payeeNumber'] == '00'
      end
    end

    def init_debts
      with_monitoring_and_error_handling do
        options = { timeout: 30 }
        DebtManagementCenter::DebtsResponse.new(
          perform(
            :post, Settings.dmc.debts_endpoint, { fileNumber: @file_number }, nil, options
          ).body
        ).debts
      end
    end

    def init_cached_debts
      Rails.cache.fetch("debts_data_#{@file_number}", expires_in: time_until_midnight) do
        with_monitoring_and_error_handling do
          options = { timeout: 30 }
          response = perform(
            :post, Settings.dmc.debts_endpoint, { fileNumber: @file_number }, nil, options
          ).body

          # Only cache if the response is an empty array
          if response.is_a?(Array) && response.empty?
            Rails.cache.write("debts_data_#{@file_number}", response, expires_in: time_until_midnight)
          end

          DebtManagementCenter::DebtsResponse.new(response).debts
        end
      end
    end

    def add_debts_to_redis
      debts = @debts.map { |d| d['id'] = SecureRandom.uuid }
      debt_params = { REDIS_CONFIG[:debt][:namespace] => user.uuid }
      debt_store = DebtManagementCenter::DebtStore.new(debt_params)
      debt_store.update(uuid: user.uuid, debts:)
    end

    def sort_by_date(debt_history)
      debt_history.sort_by { |d| Date.strptime(d['date'], '%m/%d/%Y') }.reverse
    end

    def time_until_midnight
      now = Time.now.utc
      midnight = now.beginning_of_day + 1.day
      (midnight - now).to_i.seconds
    end
  end
end
