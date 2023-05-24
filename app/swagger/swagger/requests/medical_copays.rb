# frozen_string_literal: true

module Swagger
  module Requests
    class MedicalCopays
      include Swagger::Blocks

      swagger_path '/v0/medical_copays' do
        operation :get do
          key :description, 'List of user copays for VA facilities'
          key :operationId, 'getMedicalCopays'
          key :tags, %w[medical_copays]

          parameter :authorization

          response 200 do
            key :description, 'Successful copays lookup'
            schema do
              key :required, %i[data status]
              property :data, type: :array do
                items do
                  property :id, type: :string, example: '3fa85f64-5717-4562-b3fc-2c963f66afa6'
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
                  property :pHROParaCdes, type: :string
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
              property :status, type: :integer, example: 200
            end
          end
        end
      end

      swagger_path '/v0/medical_copays/{id}' do
        operation :get do
          key :description, 'Fetch individual copay statement by id'
          key :operationId, 'getMedicalCopayById'
          key :tags, %w[medical_copays]

          parameter :authorization

          response 200 do
            key :description, 'Successful copay lookup by id'
            schema do
              key :required, %i[data status]
              property :data, type: :object do
                property :id, type: :string, example: '3fa85f64-5717-4562-b3fc-2c963f66afa6'
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
                property :pHROParaCdes, type: :string
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
              property :status, type: :integer, example: 200
            end
          end
        end
      end

      swagger_path '/v0/medical_copays/get_pdf_statement_by_id/{statement_id}' do
        operation :get do
          key :description, 'Endpoint to get PDF statement by medical_copay id'
          key :operationId, 'getPDFStatementsById'
          key :tags, %w[medical_copays]

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'The type of letter to be downloaded'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Successful PDF download'

            schema do
              property :data, type: :string, format: 'binary'
            end
          end
        end
      end

      swagger_path '/v0/medical_copays/send_statement_notifications' do
        operation :post do
          key :description, 'Endpoint to trigger notifications from new statements'
          key :operationId, 'sendNewStatementsNotifications'
          key :tags, %w[medical_copays]

          key :produces, ['application/json']
          key :consumes, ['application/json']

          parameter do
            key :name, :statements
            key :in, :body
            key :description, 'New statement data'
            key :required, true

            schema do
              key :type, :object
              key :required, [:statements]
            end
          end

          response 200 do
            key :description, 'New statement notifications sent successfully'

            schema do
              key :type, :object

              property :status, type: :integer, example: 200
              property :message, type: :string, example: 'Parsing and sending notifications'
            end
          end
        end
      end
    end
  end
end
