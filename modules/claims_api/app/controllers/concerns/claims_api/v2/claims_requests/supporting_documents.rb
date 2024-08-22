# frozen_string_literal: true

module ClaimsApi
  module V2
    module ClaimsRequests
      module SupportingDocuments
        extend ActiveSupport::Concern

        def get_evss_documents(claim_id)
          evss_docs_service.get_claim_documents(claim_id).body
        rescue => e
          claims_v2_logging('evss_doc_service', level: 'error',
                                                message: "getting docs failed in claims controller with e.message: ' \
                            '#{e.message}, rid: #{request.request_id}")
          {}
        end

        def evss_docs_service
          EVSS::DocumentsService.new(auth_headers)
        end

        def benefits_documents_enabled?
          Flipper.enabled? :claims_status_v2_lh_benefits_docs_service_enabled
        end

        def use_birls_id_file_number?
          Flipper.enabled? :lighthouse_claims_api_use_birls_id
        end
      end
    end
  end
end
