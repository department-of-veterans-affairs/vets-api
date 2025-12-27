# frozen_string_literal: true

class Swagger::V1::Requests::MedicalCopays
  include Swagger::Blocks

  swagger_path '/v1/medical_copays' do
    operation :get do
      key :description, 'List of user medical copay statements (HCCC-backed)'
      key :operationId, 'getMedicalCopays'
      key :tags, %w[medical_copays]

      parameter :authorization

      parameter do
        key :name, :count
        key :in, :query
        key :description, 'Number of Invoices to return per page'
        key :required, false
        key :type, :integer
        key :format, :int32
        key :default, 10
      end

      parameter do
        key :name, :page
        key :in, :query
        key :description, 'Page number of Invoice results'
        key :required, false
        key :type, :integer
        key :format, :int32
        key :default, 1
        key :minimum, 1
      end

      response 200 do
        key :description, 'Successful copays lookup'

        schema do
          # JSON:API top-level data
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
              end
            end
          end

          # Pagination links (built from Bundle#links)
          property :links, type: :object do
            property :self, type: :string, example: 'https://api.va.gov/v1/medical_copays?count=10&page=1'
            property :first, type: :string, example: 'https://api.va.gov/v1/medical_copays?count=10&page=1'
            property :prev, type: :string, example: 'https://api.va.gov/v1/medical_copays?count=10&page=0'
            property :next, type: :string, example: 'https://api.va.gov/v1/medical_copays?count=10&page=2'
            property :last, type: :string, example: 'https://api.va.gov/v1/medical_copays?count=10&page=5'
          end

          # Pagination meta (built from Bundle#meta)
          property :meta, type: :object do
            property :total, type: :integer, example: 50
            property :page, type: :integer, example: 1
            property :per_page, type: :integer, example: 10
          end
        end
      end
    end
  end
end
