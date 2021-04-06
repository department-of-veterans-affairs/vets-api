# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debt_management_center/debts_configuration'
require 'debt_management_center/responses/debts_response'

module DebtManagementCenter
  class DebtsService < DebtManagementCenter::BaseService
    attr_reader :file_number

    configuration DebtManagementCenter::DebtsConfiguration

    STATSD_KEY_PREFIX = 'api.dmc'

    def initialize(user)
      super(user)
      @debts = init_debts
    end

    def get_debts
      {
        has_dependent_debts: veteran_has_dependent_debts?,
        debts: debts_with_sorted_histories
      }
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
        DebtManagementCenter::DebtsResponse.new(
          perform(:post, Settings.dmc.debts_endpoint, fileNumber: @file_number).body
        ).debts
      end
    end

    def sort_by_date(debt_history)
      debt_history.sort_by { |d| Date.strptime(d['date'], '%m/%d/%Y') }.reverse
    end
  end
end
