module V0
  class PreNeedController < ApplicationController
    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    def submit
      Rails.logger.info("[PreNeedController] submit action called. Params: ")
      Rails.logger.info(params.inspect)
      Rails.logger.info("[PreNeedController] Settings.mulesoft.pre_need.mock: #{Settings.mulesoft.pre_need.mock}")

      payload = params.permit!.to_h

      # Check if mock is enabled in settings
      if Settings.mulesoft.pre_need.mock
        if payload["cmPacketNum"].blank?
          # Mock failure response
          mock_response = {
            "UUID" => "0cfa0c22-52b2-4113-a1b6-b985b841a4f8",
            "Sync_To_Salesforce" => {
              "Success" => false,
              "CaseNumber" => "",
              "ID_of_Case" => "",
              "CaseDetail_Name" => "",
              "ID_of_CaseDetail" => "",
              "Errors" => [
                { "Error1" => {
                  "parentErrorType" => { "parentErrorType" => nil, "identifier" => "ANY", "namespace" => "MULE" },
                  "identifier" => "EXPRESSION",
                  "namespace" => "MULE"
                } },
                { "Error2" => nil }
              ]
            }
          }
          render json: mock_response, status: 400
          return
        else
          # Mock success response
          mock_response = {
            "UUID" => "6b58f8a0fcc04ef5bf3f9cd7d78c3d79",
            "Location" => "https://va.lightning.force.com/500ep000004hbnIAAQ",
            "Sync_To_Salesforce" => {
              "Success" => true,
              "CaseNumber" => "12425379",
              "ID_of_Case" => "500ep000004hbnIAAQ",
              "CaseDetail_Name" => "Case Detail Name Example",
              "ID_of_CaseDetail" => "500ep000004hbnIAAQ"
            }
          }
          render json: mock_response, status: 201
          return
        end
      end

      response = Mulesoft::PreNeed::Service.new.submit_pre_need(payload)
      render json: response.body, status: response.status
    rescue => e
      Rails.logger.error("[PreNeedController] Error: #{e.message}")
      render json: { error: e.message }, status: 500
    end
  end
end
