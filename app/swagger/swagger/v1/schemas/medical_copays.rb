# frozen_string_literal: true

module Swagger
  module V1
    module Schemas
      class MedicalCopays
        include Swagger::Blocks

        swagger_schema :LighthouseMedicalCopayListResponse do
          key :type, :object

          property :data, type: :array do
            items do
              property :id, type: :string, example: '675-K3FD983'
              property :type, type: :string, example: 'medical_copays'

              property :attributes, type: :object do
                property :url,
                         type: :string,
                         example: 'https://api.va.gov/v1/medical_copays/675-K3FD983'

                property :facility,
                         type: :string,
                         example: 'TEST VAMC'

                property :city,
                         type: :string,
                         example: 'Tampa'

                property :facilityId,
                         type: :string,
                         example: '1234'

                property :externalId,
                         type: :string,
                         example: '675-K3FD983'

                property :latestBillingRef,
                         type: :string,
                         example: '4-6c9ZE23XQjkA9CC'

                property :currentBalance,
                         type: :number,
                         format: :float,
                         example: 284.59

                property :previousBalance,
                         type: :number,
                         format: :float,
                         example: 76.19

                property :previousUnpaidBalance,
                         type: :number,
                         format: :float,
                         example: 0.0

                property :lastUpdatedAt,
                         type: :string,
                         format: :'date-time',
                         example: '2012-11-01T04:00:00.000+00:00'
              end
            end
          end

          property :links, type: :object do
            property :self,
                     type: :string,
                     example: 'https://api.va.gov/v1/medical_copays?count=10&page=1'

            property :first,
                     type: :string,
                     example: 'https://api.va.gov/v1/medical_copays?count=10&page=1'

            property :prev,
                     type: :string,
                     example: 'https://api.va.gov/v1/medical_copays?count=10&page=0'

            property :next,
                     type: :string,
                     example: 'https://api.va.gov/v1/medical_copays?count=10&page=2'

            property :last,
                     type: :string,
                     example: 'https://api.va.gov/v1/medical_copays?count=10&page=5'
          end

          property :meta, type: :object do
            property :total, type: :integer, example: 50
            property :page, type: :integer, example: 1
            property :per_page, type: :integer, example: 10
          end

          property :isCerner,
                   type: :boolean,
                   example: false
        end
      end
    end
  end
end
