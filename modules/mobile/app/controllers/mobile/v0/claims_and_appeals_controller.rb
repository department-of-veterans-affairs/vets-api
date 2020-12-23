# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require_relative '../../../models/mobile/v0/adapters/claims_overview'
require_relative '../../../models/mobile/v0/adapters/claims_overview_errors'
require_relative '../../../models/mobile/v0/claim_overview'

module Mobile
  module V0
    class ClaimsAndAppealsController < ApplicationController
      include IgnoreNotFound
      before_action { authorize :evss, :access? }

      def index
        get_all_claims = lambda {
          begin
            claims_list = claims_service.all_claims
            [claims_list.body['open_claims'].push(*claims_list.body['historical_claims']).flatten, true]
          rescue => e
            [Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'claims'), false]
          end
        }

        get_all_appeals = lambda {
          begin
            [appeals_service.get_appeals(@current_user).body['data'], true]
          rescue => e
            [Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'appeals'), false]
          end
        }
        claims_result, appeals_result = Parallel.map([get_all_claims, get_all_appeals], in_threads: 2, &:call)
        status_code = parse_claims(claims_result, full_list = [], error_list = [])
        status_code = parse_appeals(appeals_result, full_list, error_list, status_code)
        adapted_full_list = serialize_list(full_list.flatten)
        render json: { data: adapted_full_list, meta: { errors: error_list } }, status: status_code
      end

      def get_claim
        claim = claims_scope.find_by(evss_id: params[:id])
        if claim
          raw_claim = claims_service.find_claim_by_id(claim.evss_id).body.fetch('claim', {})
          claim.update(data: raw_claim)
          claim_detail = EVSSClaimDetailSerializer.new(claim)
          render json: Mobile::V0::ClaimSerializer.new(claim_detail)
        else
          raise Common::Exceptions::RecordNotFound, params[:id]
        end
      end

      def get_appeal
        appeals = appeals_service.get_appeals(@current_user).body['data']
        appeal = appeals.select { |entry| entry.dig('id') == params[:id] }[0]
        if appeal
          serializable_resource = OpenStruct.new(appeal['attributes'])
          serializable_resource[:id] = appeal['id']
          serializable_resource[:type] = appeal['type']
          render json: Mobile::V0::AppealSerializer.new(serializable_resource)
        else
          raise Common::Exceptions::RecordNotFound, params[:id]
        end
      end

      def upload_documents
        params.require :file
        claim = claims_scope.find_by(evss_id: params[:id])
        raise Common::Exceptions::RecordNotFound, params[:id] unless claim

        document_data = EVSSClaimDocument.new(
          evss_claim_id: claim.evss_id,
          file_obj: params[:file],
          uuid: SecureRandom.uuid,
          file_name: params[:file].original_filename,
          tracked_item_id: params[:tracked_item_id],
          document_type: params[:document_type],
          password: params[:password]
        )
        raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

        jid = document_upload_service.upload_document(document_data)
        render json: { data: { job_id: jid } }, status: :accepted
      end

      private

      def parse_claims(claims, full_list, error_list)
        if claims[1]
          # claims success
          full_list.push(claims[0].map { |claim| create_or_update_claim(claim) })
          :ok
        else
          # claims error
          error_list.push(claims[0])
          :multi_status
        end
      end

      def parse_appeals(appeals, full_list, error_list, status_code)
        if appeals[1]
          # appeals success
          full_list.push(appeals[0])
          status_code
        else
          # appeals error
          error_list.push(appeals[0])
          status_code == :multi_status ? :bad_gateway : :multi_status
        end
      end

      def serialize_list(full_list)
        adapted_full_list = full_list.map { |entry| Mobile::V0::Adapters::ClaimsOverview.new.parse(entry) }
        adapted_full_list = adapted_full_list.sort_by { |entry| entry[:updated_at] }.reverse!
        adapted_full_list.map do |entry|
          JSON.parse(Mobile::V0::ClaimOverviewSerializer.new(entry).serialized_json)['data']
        end
      end

      def claims_service
        @claims_service ||= EVSS::ClaimsService.new(auth_headers)
      end

      def auth_headers
        @auth_headers ||= EVSS::AuthHeaders.new(@current_user).to_h
      end

      def appeals_service
        @appeals_service ||= Caseflow::Service.new
      end

      def claims_scope
        @claims_scope ||= EVSSClaim.for_user(@current_user)
      end

      def document_upload_service
        @document_upload_service ||= EVSSClaimService.new(@current_user)
      end

      def create_or_update_claim(raw_claim)
        claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
        claim.update(list_data: raw_claim)
        claim
      end
    end
  end
end
