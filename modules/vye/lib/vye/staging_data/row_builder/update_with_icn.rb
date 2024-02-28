# frozen_string_literal: true

module Vye
  module StagingData
    module RowBuilder
      Vye::StagingData::RowBuilder::UpdateWithIcn = Struct.new(:index, :csv) do
        include Common

        def call
          values => {ssn:, icn:, full_name:}

          index.tap do |_|
            next if ssn.blank? || icn.blank? || index[ssn].blank?

            check_full_names!

            if index[ssn].all? { |v| v[:icn].blank? }
              index[ssn].each { |v| v[:icn] = icn }
            elsif index[ssn].all? { |v| v[:icn] == icn }
              nil # no-op
            else
              icns = index[ssn].pluck(:icn)
              raise format(
                'icn missmatch: %<icn>s vs %<icns>p)',
                { icn:, icns: }
              )
            end
          end
        end

        private

        def check_full_names!
          values => {ssn:, icn:, full_name:}

          return if index[ssn].all? { |row| row[:full_name] == full_name }

          new_full_name = index[ssn].pluck(:full_name).push(full_name).max { |a, b| a.length <=> b.length }
          index[ssn].each { |v| v[:full_name] = new_full_name }
        end

        def get_values
          ssn = extract_ssn
          icn = csv['icn']&.strip
          full_name =
            csv.values_at(
              'first_name',
              'middle_name',
              'last_name'
            ).compact.map(&:strip).map(&:capitalize).join(' ').strip
          { ssn:, icn:, full_name: }
        end

        def values
          @values ||= get_values
        end
      end
    end
  end
end
