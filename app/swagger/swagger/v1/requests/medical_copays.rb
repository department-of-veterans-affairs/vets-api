# frozen_string_literal: true

class Swagger::V1::Requests::MedicalCopays
  include Swagger::Blocks

  swagger_path '/v1/medical_copays' do
    operation :get do
      key :description, 'List of user medical copay statements (HCCC-backed)'
      key :operationId, 'getMedicalCopays'
      key :tags, %w[medical_copays]

      parameter :authorization

      response 200 do
        key :description, 'Successful copays lookup'

        schema do
          property :isCerner, type: :boolean, example: false
          property :status, type: :integer, example: 200
          # Lighthouse response (conditionally returned based on Cerner location(s))
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

              # VBS response (conditionally returned based on Cerner location(s))
              property :accountNumber, type: :string
              property :pSSeqNum, type: :integer, example: 0
              property :pSTotSeqNum, type: :integer, example: 0
              property :pSFacilityNum, type: :string
              property :pSFacPhoneNum, type: :string
              property :pSTotStatement, type: :integer, example: 0
              property :pSStatementVal, type: :string
              property :pSStatementDate, type: :string
              property :pSStatementDateOutput, type: :string
              property :pSProcessDate, type: :string
              property :pSProcessDateOutput, type: :string
              property :pHPatientLstNme, type: :string
              property :pHPatientFstNme, type: :string
              property :pHPatientMidNme, type: :string
              property :pHAddress1, type: :string
              property :pHAddress2, type: :string
              property :pHAddress3, type: :string
              property :pHCity, type: :string
              property :pHState, type: :string
              property :pHZipCde, type: :string
              property :pHZipCdeOutput, type: :string
              property :pHCtryNme, type: :string
              property :pHAmtDue, type: :integer, example: 0
              property :pHAmtDueOutput, type: :string
              property :pHPrevBal, type: :integer, example: 0
              property :pHPrevBalOutput, type: :string
              property :pHTotCharges, type: :integer, example: 0
              property :pHTotChargesOutput, type: :string
              property :pHTotCredits, type: :integer, example: 0
              property :pHTotCreditsOutput, type: :string
              property :pHNewBalance, type: :integer, example: 0
              property :pHNewBalanceOutput, type: :string
              property :pHSpecialNotes, type: :string
              property :pHroParaCdes, type: :string
              property :pHNumOfLines, type: :integer, example: 0
              property :pHDfnNumber, type: :integer, example: 0
              property :pHCernerStatementNumber, type: :integer, example: 0
              property :pHCernerPatientId, type: :string
              property :pHCernerAccountNumber, type: :string
              property :pHIcnNumber, type: :string
              property :pHAccountNumber, type: :integer, example: 0
              property :pHLargeFontIndcator, type: :integer, example: 0
              property :details, type: :array do
                items do
                  property :pDDatePosted, type: :string
                  property :pDDatePostedOutput, type: :string
                  property :pDTransDesc, type: :string
                  property :pDTransDescOutput, type: :string
                  property :pDTransAmt, type: :integer, example: 0
                  property :pDTransAmtOutput, type: :string
                  property :pDRefNo, type: :string
                end
              end
              property :station, type: :object do
                property :facilitYNum, type: :string
                property :visNNum, type: :string
                property :facilitYDesc, type: :string
                property :cyclENum, type: :string
                property :remiTToFlag, type: :string
                property :maiLInsertFlag, type: :string
                property :staTAddress1, type: :string
                property :staTAddress2, type: :string
                property :staTAddress3, type: :string
                property :city, type: :string
                property :state, type: :string
                property :ziPCde, type: :string
                property :ziPCdeOutput, type: :string
                property :baRCde, type: :string
                property :teLNumFlag, type: :string
                property :teLNum, type: :string
                property :teLNum2, type: :string
                property :contacTInfo, type: :string
                property :dM2TelNum, type: :string
                property :contacTInfo2, type: :string
                property :toPTelNum, type: :string
                property :lbXFedexAddress1, type: :string
                property :lbXFedexAddress2, type: :string
                property :lbXFedexAddress3, type: :string
                property :lbXFedexCity, type: :string
                property :lbXFedexState, type: :string
                property :lbXFedexZipCde, type: :string
                property :lbXFedexBarCde, type: :string
                property :lbXFedexContact, type: :string
                property :lbXFedexContactTelNum, type: :string
              end
            end
          end

          # Only in Lighthouse response (conditionally returned based on Cerner location(s))c
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
