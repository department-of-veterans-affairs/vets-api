# frozen_string_literal: true

module Mobile
  module V0
    module Claims
      class Proxy
        STATSD_UPLOAD_LATENCY = 'mobile.api.claims.upload.latency'

        def initialize(user)
          @user = user
        end

        def get_claim(id)
          claim = claims_scope.find_by(evss_id: id)
          claim_not_found(id, __method__) unless claim

          raw_claim = claims_service.find_claim_with_docs_by_id(claim.evss_id).body.fetch('claim', {})
          claim.update(data: raw_claim)
          claim['updated_at'] = claim['updated_at'].to_time.iso8601
          EVSSClaimDetailSerializer.new(claim)
        rescue EVSS::ErrorMiddleware::EVSSError => e
          handle_middleware_error(e)
        end

        def get_appeal(id)
          appeals = appeals_service.get_appeals(@user).body['data']
          appeal = appeals.filter { |entry| entry['id'] == id }[0]
          raise Common::Exceptions::RecordNotFound, id unless appeal

          serializable_resource = OpenStruct.new(appeal['attributes'])
          serializable_resource[:id] = appeal['id']
          serializable_resource[:type] = appeal['type']
          serializable_resource
        rescue EVSS::ErrorMiddleware::EVSSError => e
          handle_middleware_error(e)
        end

        def request_decision(id)
          claim = EVSSClaim.for_user(@user).find_by(evss_id: id)
          claim_not_found(id, __method__) unless claim

          jid = evss_claim_service.request_decision(claim)
          claim.update(requested_decision: true)
          jid
        end

        def upload_document(params)
          start_timer = Time.zone.now
          params.require :file
          id = params[:id]
          claim = claims_scope.find_by(evss_id: id)
          claim_not_found(id, __method__) unless claim

          jid = submit_document(params[:file], id, params[:trackedItemId], params[:documentType], params[:password])
          StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ['is_multifile:false'])
          jid
        end

        def upload_multi_image(params)
          start_timer = Time.zone.now
          params.require :files
          id = params[:id]
          claim = claims_scope.find_by(evss_id: id)
          claim_not_found(id, __method__) unless claim

          file_to_upload = generate_multi_image_pdf(params[:files])
          jid = submit_document(file_to_upload, id, params[:tracked_item_id], params[:document_type], params[:password])
          StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ['is_multifile:true'])
          jid
        end

        def cleanup_after_upload
          FileUtils.rm_rf(@base_path) if @base_path
        end

        def get_all_claims
          lambda {
            begin
              claims_list = claims_service.all_claims
              {
                list: claims_list.body['open_claims']
                                 .push(*claims_list.body['historical_claims'])
                                 .flatten
                                 .map { |claim| create_or_update_claim(claim) },
                errors: nil
              }
            rescue => e
              { list: nil, errors: Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'claims') }
            end
          }
        end

        def get_all_appeals
          lambda {
            begin
              { list: appeals_service.get_appeals(@user).body['data'], errors: nil }
            rescue => e
              { list: nil, errors: Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'appeals') }
            end
          }
        end

        private

        def submit_document(file, claim_id, tracked_item_id, document_type, password)
          document_data = EVSSClaimDocument.new(evss_claim_id: claim_id, file_obj: file, uuid: SecureRandom.uuid,
                                                file_name: file.original_filename, tracked_item_id:,
                                                document_type:, password:)
          Rails.logger.info('claim_id', claim_id:)
          Rails.logger.info('document_type', document_type:)
          Rails.logger.info('file_name present?', file&.original_filename.present?)
          Rails.logger.info('file extension', file&.original_filename&.split('.')&.last)
          Rails.logger.info('file content type', file&.content_type)

          raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

          evss_claim_service.upload_document(document_data)
        end

        def auth_headers
          @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
        end

        def appeals_service
          @appeals_service ||= Caseflow::Service.new
        end

        def claims_service
          @claims_service ||= EVSS::ClaimsService.new(auth_headers)
        end

        def evss_claim_service
          @evss_claim_service ||= EVSSClaimService.new(@user)
        end

        def serialize_list(full_list)
          adapted_full_list = Mobile::V0::Adapters::ClaimsOverview.new.parse(full_list)
          adapted_full_list = adapted_full_list.sort_by(&:updated_at).reverse!
          adapted_full_list.map do |entry|
            Mobile::V0::ClaimOverviewSerializer.new(entry).serializable_hash['data']
          end
        end

        def create_or_update_claim(raw_claim)
          claim = claims_scope.where(evss_id: raw_claim['id']).first
          if claim.blank?
            claim = EVSSClaim.new(user_uuid: @user.uuid,
                                  user_account: @user.user_account,
                                  evss_id: raw_claim['id'],
                                  data: {})
          end
          claim.update(list_data: raw_claim)
          claim
        end

        def claims_scope
          @claims_scope ||= EVSSClaim.for_user(@user)
        end

        # temporary logging for better understanding why claims are sometimes not found
        def claim_not_found(id, method)
          Rails.logger.info("Mobile user #{@user.uuid} claim #{id} not found for method #{method}")
          raise Common::Exceptions::RecordNotFound, id
        end

        def generate_multi_image_pdf(image_list)
          @base_path = Rails.root.join 'tmp', 'uploads', 'cache', SecureRandom.uuid
          img_path = "#{@base_path}/tempFile.jpg"
          pdf_filename = 'multifile.pdf'
          pdf_path = "#{@base_path}/#{pdf_filename}"
          FileUtils.mkpath @base_path
          Prawn::Document.generate(pdf_path) do |pdf|
            image_list.each do |img|
              File.binwrite(img_path, Base64.decode64(img))
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

        def handle_middleware_error(error)
          response_values = {
            details: error.details
          }
          raise Common::Exceptions::BackendServiceException.new('MOBL_502_upstream_error', response_values, 500,
                                                                error.body)
        end
      end
    end
  end
end
