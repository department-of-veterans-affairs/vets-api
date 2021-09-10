# frozen_string_literal: true

module AppealsApi
  module V2
    module Schemas
      class LegacyAppeals
        include Swagger::Blocks

        swagger_component do
          schema :legacyAppeal do
            property :id do
              key :type, :string
              key :description, 'ID from VACOLS (Veteran Appeals Control and Locator Service)'
              key :example, '3085659'
            end
            property :type do
              key :type, :string
              key :description, 'Appeal Type'
              key :value, 'legacyAppeal'
            end

            property :issues do
              key :type, :array
              key :description, 'Issues on Appeal'

              items do
                property :summary do
                  key :type, :string
                  key :description, 'Summary of a single Issue description'
                  key :example, 'Service connection, hearing loss'
                end
              end
            end

            property :veteranFullName do
              key :type, :string
              key :example, 'Junior L Fritsch'
            end

            property :decisionDate do
              key :type, :string
              key :description, 'Date of the Appeal\'s original decision'
              key :example, '2018-09-28T00:00:00.000Z'
            end

            property :latestSocSsocDate do
              key :type, :string
              key :description, 'Date of the Appeal\'s most recent SOC/SSOC'
              key :example, '2018-12-29T00:00:00.000Z'
            end
          end
        end
      end
    end
  end
end
