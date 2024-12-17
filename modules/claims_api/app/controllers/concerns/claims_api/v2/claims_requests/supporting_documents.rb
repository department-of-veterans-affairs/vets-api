# frozen_string_literal: true

module ClaimsApi
  module V2
    module ClaimsRequests
      module SupportingDocuments
        extend ActiveSupport::Concern

        # rubocop:disable Metrics/MethodLength
        def build_supporting_docs(bgs_claim, ssn)
          return [] if bgs_claim.nil?

          @supporting_documents = []
          file_number = get_file_number(ssn)
          return [] if file_number.nil?

          docs = if benefits_documents_enabled?
                   claims_v2_logging('benefits_documents',
                                     message: "calling benefits documents api for claim_id #{params[:id]} " \
                                              'in claims controller v2')
                   supporting_docs_list = benefits_doc_api.search(params[:id],
                                                                  file_number)&.dig(:data)
                   # add with_indifferent_access so ['documents'] works below
                   # we can remove when EVSS is gone and access it via it's symbol
                   supporting_docs_list.with_indifferent_access if supporting_docs_list.present?
                 else
                   get_evss_documents(bgs_claim[:benefit_claim_details_dto][:benefit_claim_id])
                 end
          return [] if docs.nil? || docs&.dig('documents').blank?

          @supporting_documents = docs['documents'].map do |doc|
            doc = doc.transform_keys(&:underscore) if benefits_documents_enabled?
            upload_date = upload_date(doc['upload_date']) || bd_upload_date(doc['uploaded_date_time'])
            {
              document_id: doc['document_id'],
              document_type_label: doc['document_type_label'],
              original_file_name: doc['original_file_name'],
              tracked_item_id: doc['tracked_item_id'],
              upload_date:
            }
          end
        end
        # rubocop:enable Metrics/MethodLength

        def get_file_number(ssn)
          file_number = if use_birls_id_file_number?
                          target_veteran.birls_id
                        else
                          find_by_ssn(ssn)&.dig(:file_nbr)
                        end

          if file_number.blank?
            claims_v2_logging('benefits_documents',
                              message: "calling benefits documents api for claim_id: #{params[:id]} " \
                                       'returned a nil file number in claims controller v2')
            return nil
          end
          file_number
        end

        def get_evss_documents(claim_id)
          evss_docs_service.get_claim_documents(claim_id).body
        rescue => e
          claims_v2_logging('evss_doc_service', level: 'error',
                                                message: "getting docs failed in claims controller with e.message: ' \
                            '#{e.message}, rid: #{request.request_id}")
          {}
        end

        # duplicating temporarily to bd_upload_date. remove when EVSS call is gone
        def upload_date(upload_date)
          return if upload_date.nil?

          Time.zone.at(upload_date / 1000).strftime('%Y-%m-%d')
        end

        def bd_upload_date(upload_date)
          return if upload_date.nil?

          Date.parse(upload_date).strftime('%Y-%m-%d')
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

        def find_by_ssn(ssn)
<<<<<<< HEAD
          if Flipper.enabled? :claims_api_use_person_web_service
            # rubocop:disable Rails/DynamicFindBy
            ClaimsApi::PersonWebService.new(
              external_uid: target_veteran.participant_id,
              external_key: target_veteran.participant_id
            ).find_by_ssn(ssn)
          else
            ClaimsApi::LocalBGS.new(
              external_uid: target_veteran.participant_id,
              external_key: target_veteran.participant_id
            ).find_by_ssn(ssn)
            # rubocop:enable Rails/DynamicFindBy
          end
=======
          # rubocop:disable Rails/DynamicFindBy
          ClaimsApi::PersonWebService.new(
            external_uid: target_veteran.participant_id,
            external_key: target_veteran.participant_id
          ).find_by_ssn(ssn)
          # rubocop:enable Rails/DynamicFindBy
>>>>>>> ef3c0288176bba86adfb7abaf6e3a2c9bd88c1aa
        end
      end
    end
  end
end
