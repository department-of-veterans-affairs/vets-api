# frozen_string_literal: true

require 'debts_api/v0/fsr_form_transform/utils'
include FsrFormTransform::Utils

module DebtsApi
  module V0
    module FsrFormTransform
      class AssetCalculator

        CASH_IN_BANK = 'Cash in a bank (savings and checkings)';
        CASH_ON_HAND = 'Cash on hand (not in bank)';
        US_BONDS = 'U.S. Savings Bonds'

        def initialize(form)
          @form = form
          @enhanced_fsr_active = @form['view:enhanced_financial_status_report']
          @assets = @form['assets']
          
          @monetary_assets = @assets['monetary_assets'] || []
          @cash_on_hand = sum_values(@monetary_assets.select{|asset| asset['name'] == CASH_ON_HAND}, 'amount')
          @cash_in_bank = sum_values(@monetary_assets.select{|asset| asset['name'] == CASH_IN_BANK}, 'amount')
          @us_savings_bonds = @monetary_assets.select{|asset| asset['name'] == US_BONDS}
          
          @other_assets = @assets.dig('other_assets')
          @automobiles = @assets.dig('automobiles')
          @rec_vehicle_amount = @assets.dig('rec_vehicle_amount')
          @real_estate_value = @assets['real_estate_value']&.gsub(/[^0-9.-]/, '')&.to_f || 0.0
          @real_estate_records = @form['real_estate_records']
          @questions = @form['questions']
        end

        def default_output
          {
            'cashInBank' => '0.00',
            'cashOnHand' => '0.00',
            'automobiles' => [],
            'trailersBoatsCampers' => '0.00',
            'usSavingsBonds' => '0.00',
            'stocksAndOtherBonds' => '0.00',
            'realEstateOwned' => '0.00',
            'otherAssets' => [],
            'totalAssets' => '0.00' 
          }
        end

        def transform_assets
          output = default_output
          output['cashInBank'] = dollars_cents(@cash_in_bank) if @cash_in_bank 
          output['cashOnHand'] = dollars_cents(@cash_on_hand) if @cash_on_hand
          output['automobiles'] = @automobiles if @automobiles
          output['trailersBoatsCampers'] = @rec_vehicle_amount if @rec_vehicle_amount
          output['usSavingsBonds'] = dollars_cents(sum_values(@us_savings_bonds, 'amount').to_f)
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
                         @assets.values.reject { |item| item && !item.is_a?(Array) }
                                .reduce(0) { |acc, amount| (acc + amount&.gsub(/[^0-9.-]/, '')&.to_f) || 0 }
                       end

          tot_vehicles + tot_rec_vehicles + tot_other_assets + real_estate + tot_assets
        end

        private

        def sum_values(collection, key)
          collection&.sum { |item| item[key]&.gsub(/[^0-9.-]/, '')&.to_f } || 0
        end 
      end
    end
  end
end
