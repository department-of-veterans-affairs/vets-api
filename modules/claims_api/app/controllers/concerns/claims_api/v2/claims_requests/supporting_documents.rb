# frozen_string_literal: true

module ClaimsApi
  module V2
    module ClaimsRequests
      module SupportingDocuments
        extend ActiveSupport::Concern

        def build_supporting_docs(bgs_claim, ssn)
          return [] if bgs_claim.nil?

          @supporting_documents = []
          file_number = get_file_number(ssn)
          return [] if file_number.nil?

          claims_v2_logging('benefits_documents',
                            message: "calling benefits documents api for claim_id #{params[:id]} " \
                                     'in claims controller v2')
          docs = benefits_doc_api.search(params[:id], file_number)&.dig(:data)

          return [] if docs.nil? || docs&.dig(:documents).blank?

          @supporting_documents = transform_documents(docs)
        end

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

        def transform_documents(docs)
          docs[:documents].map do |doc|
            doc = doc.transform_keys { |key| key.to_s.underscore }
            upload_date_value = doc['upload_date']
            uploaded_date_time_value = doc['uploaded_date_time']

            {
              document_id: doc['document_id'],
              document_type_label: doc['document_type_label'],
              original_file_name: doc['original_file_name'],
              tracked_item_id: doc['tracked_item_id'],
              upload_date: upload_date(upload_date_value) || bd_upload_date(uploaded_date_time_value),
              upload_date_time: upload_date_value || uploaded_date_time_value
            }
          end
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

        def use_birls_id_file_number?
          Flipper.enabled? :lighthouse_claims_api_use_birls_id
        end

        def find_by_ssn(ssn)
          # rubocop:disable Rails/DynamicFindBy
          ClaimsApi::PersonWebService.new(
            external_uid: target_veteran.participant_id,
            external_key: target_veteran.participant_id
          ).find_by_ssn(ssn)
          # rubocop:enable Rails/DynamicFindBy
        end
      end
    end
  end
end
