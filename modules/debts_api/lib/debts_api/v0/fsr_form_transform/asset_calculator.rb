# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/utils'

module DebtsApi
  module V0
    module FsrFormTransform
      class AssetCalculator
        include ::FsrFormTransform::Utils

        CASH_IN_BANK = 'Cash in a bank (savings and checkings)'
        CASH_ON_HAND = 'Cash on hand (not in bank)'
        US_BONDS = 'U.S. Savings Bonds'
        OTHER_STOCK_FILTER = [
          'Other stocks and bonds (not in your retirement accounts)',
          'Retirement accounts (401k, IRAs, 403b, TSP)',
          'Pension',
          'Cryptocurrency'
        ].freeze

        def initialize(form)
          @form = form
          @enhanced_fsr_active = @form['view:enhanced_financial_status_report']
          @assets = @form['assets']

          @monetary_assets = @assets['monetary_assets'] || []
          @questions = @form['questions'] || {}
          @cash_on_hand = sum_values(@monetary_assets.select { |asset| asset['name'] == CASH_ON_HAND }, 'amount')
          @cash_in_bank = sum_values(@monetary_assets.select { |asset| asset['name'] == CASH_IN_BANK }, 'amount')
          @us_savings_bonds = @monetary_assets.select { |asset| asset['name'] == US_BONDS }
          @stock_bond_etc = sum_values(@monetary_assets.select do |asset|
                                         OTHER_STOCK_FILTER.include?(asset['name'])
                                       end, 'amount').to_f

          @other_assets = @assets['other_assets']
          @automobiles = @assets['automobiles']
          @rec_vehicle_amount = @assets['rec_vehicle_amount']
          @real_estate_value = @assets['real_estate_value']&.gsub(/[^0-9.-]/, '').to_f
          @real_estate_records = @form['real_estate_records']
        end

        def transform_assets
          output = default_output
          output['cashInBank'] = dollars_cents(@cash_in_bank) if @cash_in_bank
          output['cashOnHand'] = dollars_cents(@cash_on_hand) if @cash_on_hand
          output['automobiles'] = @automobiles if @automobiles
          output['trailersBoatsCampers'] = @rec_vehicle_amount if @rec_vehicle_amount
          output['usSavingsBonds'] = dollars_cents(sum_values(@us_savings_bonds, 'amount').to_f)
          output['stocksAndOtherBonds'] = dollars_cents(@stock_bond_etc)
          output['realEstateOwned'] = dollars_cents(@real_estate_value) if @real_estate_value
          output['otherAssets'] = @other_assets if @other_assets
          output['totalAssets'] = dollars_cents(get_total_assets)
          re_camel(output)
        end

        def get_total_assets
          tot_other_assets = sum_values(@assets['other_assets'], 'amount')
          tot_rec_vehicles = @enhanced_fsr_active ? @assets['rec_vehicle_amount']&.gsub(/[^0-9.-]/, '')&.to_f || 0 : 0
          tot_vehicles = @questions['has_vehicle'] ? sum_values(@assets['automobiles'], 'resale_value') : 0
          real_estate = if @enhanced_fsr_active
                          @real_estate_value
                        else
                          sum_values(@real_estate_records,
                                     'real_estate_amount')
                        end
          tot_assets = if @enhanced_fsr_active
                         sum_values(@assets['monetary_assets'], 'amount')
                       else
                         @assets.values.select { |item| item.is_a?(Array) }
                                .flatten
                                .map { |value| value.to_s.gsub(/[^0-9.-]/, '').to_f }
                                .sum
                       end

          tot_vehicles + tot_rec_vehicles + tot_other_assets + real_estate + tot_assets
        end

        private

        def default_output
          {
            'cashInBank' => '0.00',
            'cashOnHand' => '0.00',
            'usSavingsBonds' => '0.00',
            'stocksAndOtherBonds' => '0.00',
            'realEstateOwned' => '0.00',
            'totalAssets' => '0.00'
          }
        end
      end
    end
  end
end
