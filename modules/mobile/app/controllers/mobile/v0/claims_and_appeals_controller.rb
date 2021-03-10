# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require_relative '../../../models/mobile/v0/adapters/claims_overview'
require_relative '../../../models/mobile/v0/adapters/claims_overview_errors'
require_relative '../../../models/mobile/v0/claim_overview'
require 'sentry_logging'
require 'prawn'
require 'fileutils'
require 'mini_magick'

module Mobile
  module V0
    class ClaimsAndAppealsController < ApplicationController
      include IgnoreNotFound
      STATSD_UPLOAD_LATENCY = 'mobile.api.claims.upload.latency'
      before_action { authorize :evss, :access? }
      after_action do
        (FileUtils.rm_rf(@base_path) if File.exist?(@base_path)) if @base_path
      end

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

          StatsD.increment(
            'mobile.claims_and_appeals.claim.type',
            tags: %W[
              base_end_product_code#{claim['base_end_product_code']}
              base_end_product_code#{claim['benefit_claim_type_code']}
            ],
            sample_rate: 1.0
          )

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

      def request_decision
        claim = EVSSClaim.for_user(current_user).find_by(evss_id: params[:id])
        jid = evss_claim_service.request_decision(claim)
        Rails.logger.info('Mobile Request', {
                            claim_id: params[:id],
                            job_id: jid
                          })
        claim.update(requested_decision: true)
        render json: { data: { job_id: jid } }, status: :accepted
      end

      def upload_documents
        start_timer = Time.zone.now
        params.require :file
        id = params[:id]
        file = params[:file]
        claim = claims_scope.find_by(evss_id: id)
        raise Common::Exceptions::RecordNotFound, id unless claim

        file_to_upload = params[:multifile] ? generate_multi_image_pdf(file) : file
        document_data = EVSSClaimDocument.new(evss_claim_id: id, file_obj: file_to_upload,
                                              uuid: SecureRandom.uuid, file_name: file_to_upload.original_filename,
                                              tracked_item_id: params[:tracked_item_id],
                                              document_type: params[:document_type], password: params[:password])
        raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

        jid = evss_claim_service.upload_document(document_data)
        Rails.logger.info('Mobile Request', { claim_id: id, job_id: jid })
        StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ["is_multifile:#{params[:multifile]}"])
        render json: { data: { job_id: jid } }, status: :accepted
      end

      private

      def generate_multi_image_pdf(image_list)
        @base_path = Rails.root.join 'tmp', 'uploads', 'cache', SecureRandom.uuid
        img_path = "#{@base_path}/tempFile.jpg"
        pdf_filename = 'multifile.pdf'
        pdf_path = "#{@base_path}/#{pdf_filename}"
        FileUtils.mkpath @base_path
        Prawn::Document.generate(pdf_path) do |pdf|
          image_list.each do |img|
            File.open(img_path, 'wb') { |f| f.write Base64.decode64(img) }
            img = MiniMagick::Image.open(img_path)
            if img.height > pdf.bounds.top || img.width > pdf.bounds.right
              pdf.image img_path, fit: [pdf.bounds.right, pdf.bounds.top]
            else
              pdf.image img_path
            end
            pdf.start_new_page unless pdf.page_count == image_list.length
          end
        end
        temp_file = Tempfile.new(pdf_filename, encoding: 'ASCII-8BIT')
        temp_file.write(File.read(pdf_path))
        ActionDispatch::Http::UploadedFile.new(filename: pdf_filename, type: 'application/pdf', tempfile: temp_file)
      end

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

      def evss_claim_service
        @evss_claim_service ||= EVSSClaimService.new(@current_user)
      end

      def create_or_update_claim(raw_claim)
        claim = claims_scope.where(evss_id: raw_claim['id']).first_or_initialize(data: {})
        claim.update(list_data: raw_claim)
        claim
      end
    end
  end
end
