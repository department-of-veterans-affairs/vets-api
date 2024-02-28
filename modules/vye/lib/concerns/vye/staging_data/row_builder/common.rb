# frozen_string_literal: true

module Vye
  module StagingData
    module RowBuilder
      module Common
        def extract_ssn
          csv['ssn']&.gsub(/\D/, '')&.strip
        end
      end
    end
  end
end
