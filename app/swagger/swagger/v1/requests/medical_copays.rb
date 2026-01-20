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

  swagger_path '/v1/medical_copays/{id}' do
    operation :get do
      key :description, 'Fetch detailed medical copay invoice by ID (HCCC-backed)'
      key :operationId, 'getMedicalCopayById'
      key :tags, %w[medical_copays]

      parameter :authorization

      parameter do
        key :name, :id
        key :in, :path
        key :description, 'External ID of the copay invoice (e.g., 675-K3FD983)'
        key :required, true
        key :type, :string
      end

      response 200 do
        key :description, 'Successful copay detail lookup'

        schema do
          # JSON:API top-level data (single resource)
          property :data, type: :object do
            property :id, type: :string, example: '675-K3FD983'
            property :type, type: :string, example: 'medicalCopayDetails'

            property :attributes, type: :object do
              property :externalId,
                       type: :string,
                       example: '675-K3FD983'

              property :facility,
                       type: :string,
                       example: 'TEST VAMC'

              property :billNumber,
                       type: :string,
                       example: 'BILL-123456'

              property :status,
                       type: :string,
                       example: 'issued'

              property :statusDescription,
                       type: :string,
                       example: 'Balance due'

              property :invoiceDate,
                       type: :string,
                       example: '2024-01-15'

              property :paymentDueDate,
                       type: :string,
                       example: '2024-02-14'

              property :accountNumber,
                       type: :string,
                       example: 'ACCT-789012'

              property :originalAmount,
                       type: :number,
                       format: :float,
                       example: 500.0

              property :principalBalance,
                       type: :number,
                       format: :float,
                       example: 284.59

              property :interestBalance,
                       type: :number,
                       format: :float,
                       example: 0.0

              property :administrativeCostBalance,
                       type: :number,
                       format: :float,
                       example: 0.0

              property :principalPaid,
                       type: :number,
                       format: :float,
                       example: 215.41

              property :interestPaid,
                       type: :number,
                       format: :float,
                       example: 0.0

              property :administrativeCostPaid,
                       type: :number,
                       format: :float,
                       example: 0.0

              property :lineItems, type: :array do
                items do
                  property :billingReference, type: :string, example: '4-6c9ZE23XQjkA9CC'
                  property :datePosted, type: :string, example: '2024-01-10'
                  property :description, type: :string, example: 'Outpatient Care'
                  property :providerName, type: :string, example: 'TEST VAMC'

                  property :priceComponents, type: :array do
                    items do
                      property :type, type: :string, example: 'base'
                      property :code, type: :string, example: 'Copay Amount'
                      property :amount, type: :number, format: :float, example: 50.0
                    end
                  end

                  property :medication, type: :object do
                    property :medicationName, type: :string, example: 'Lisinopril 10mg Tablet'
                    property :rxNumber, type: :string, example: 'RX-123456'
                    property :quantity, type: :number, example: 30
                    property :daysSupply, type: :integer, example: 30
                  end
                end
              end

              property :payments, type: :array do
                items do
                  property :paymentId, type: :string, example: 'PMT-001'
                  property :paymentDate, type: :string, example: '2024-01-20'
                  property :paymentAmount, type: :number, format: :float, example: 100.0
                  property :transactionNumber, type: :string, example: 'TXN-789'
                  property :billNumber, type: :string, example: 'BILL-123456'
                  property :invoiceReference, type: :string, example: '675-K3FD983'
                  property :disposition, type: :string, example: 'Complete'

                  property :detail, type: :array do
                    items do
                      property :type, type: :string, example: 'Principal'
                      property :amount, type: :number, format: :float, example: 100.0
                    end
                  end
                end
              end
            end

            # Response meta
            property :meta, type: :object do
              property :line_item_count, type: :integer, example: 3
              property :payment_count, type: :integer, example: 1
            end
          end
        end
      end
    end
  end
end
