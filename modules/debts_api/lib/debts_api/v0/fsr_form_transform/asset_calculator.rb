# frozen_string_literal: true

module DebtsApi
  module V0
    module FsrFormTransform
      class AssetCalculator
        def initialize(form)
          @form = form
          @enhanced_fsr_active = @form['view:enhanced_financial_status_report']
          @assets = @form['assets']
          @real_estate_records = @form['real_estate_records']
          @questions = @form['questions']
        end

        def get_total_assets
          formatted_re_value = @assets['real_estate_value']&.gsub(/[^0-9.-]/, '')&.to_f || 0
          tot_other_assets = sum_values(@assets['other_assets'], 'amount')
          tot_rec_vehicles = @enhanced_fsr_active ? @assets['rec_vehicle_amount']&.gsub(/[^0-9.-]/, '')&.to_f || 0 : 0
          tot_vehicles = @questions['has_vehicle'] ? sum_values(@assets['automobiles'], 'resale_value') : 0
          real_estate = if @enhanced_fsr_active
                          formatted_re_value
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
