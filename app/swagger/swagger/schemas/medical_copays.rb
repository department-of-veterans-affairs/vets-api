# frozen_string_literal: true

module Swagger
  module Schemas
    class MedicalCopays
      include Swagger::Blocks

      swagger_schema :VbsMedicalCopayListResponse do
        key :type, :object
        key :required, %i[data status]

        property :data, type: :array do
          items do
            property :id, type: :string, example: '3fa85f64-5717-4562-b3fc-2c963f66afa6'
            property :pSSeqNum, type: :integer
            property :pSTotSeqNum, type: :integer
            property :pSFacilityNum, type: :string
            property :pSFacPhoneNum, type: :string
            property :pSTotStatement, type: :integer
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
            property :pHAmtDue, type: :integer
            property :pHAmtDueOutput, type: :string
            property :pHPrevBal, type: :integer
            property :pHPrevBalOutput, type: :string
            property :pHTotCharges, type: :integer
            property :pHTotChargesOutput, type: :string
            property :pHTotCredits, type: :integer
            property :pHTotCreditsOutput, type: :string
            property :pHNewBalance, type: :integer
            property :pHNewBalanceOutput, type: :string
            property :pHSpecialNotes, type: :string
            property :pHROParaCdes, type: :string
            property :pHNumOfLines, type: :integer
            property :pHDfnNumber, type: :integer
            property :pHCernerStatementNumber, type: :integer
            property :pHCernerPatientId, type: :string
            property :pHCernerAccountNumber, type: :string
            property :pHIcnNumber, type: :string
            property :pHAccountNumber, type: :integer
            property :pHLargeFontIndcator, type: :integer

            property :details, type: :array do
              items do
                property :pDDatePosted, type: :string
                property :pDDatePostedOutput, type: :string
                property :pDTransDesc, type: :string
                property :pDTransDescOutput, type: :string
                property :pDTransAmt, type: :integer
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
        property :isCerner, type: :boolean, example: true
      end
    end
  end
end
