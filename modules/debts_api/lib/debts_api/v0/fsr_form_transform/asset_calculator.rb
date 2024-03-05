# frozen_string_literal: true

module DebtsApi
  module V0
    module FsrFormTransform
      class AssetCalculator
        def initialize(form)
          @form = form
          @enhanced_fsr_active = @form['view:enhancedFinancialStatusReport']
          @assets = @form['assets']
          @real_estate_records = @form['realEstateRecords']
          @questions = @form['questions']
        end

        def get_total_assets
          formatted_re_value = @assets['realEstateValue']&.gsub(/[^0-9.-]/, '')&.to_f || 0
          tot_other_assets = sum_values(@assets['otherAssets'], 'amount')
          tot_rec_vehicles = @enhanced_fsr_active ? @assets['recVehicleAmount']&.gsub(/[^0-9.-]/, '')&.to_f || 0 : 0
          tot_vehicles = @questions['hasVehicle'] ? sum_values(@assets['automobiles'], 'resaleValue') : 0
          real_estate = if @enhanced_fsr_active
                          formatted_re_value
                        else
                          sum_values(@real_estate_records,
                                     'realEstateAmount')
                        end
          tot_assets = if @enhanced_fsr_active
                         sum_values(@assets['monetaryAssets'], 'amount')
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
