# frozen_string_literal: true

module ClaimsApi
  class IntentToFileSerializer < ActiveModel::Serializer
    attribute :creation_date
    attribute :expiration_date
    attribute :type
    attribute :status

    type :intent_to_file

    def id
      object[:intent_to_file_id]
    end

    def type
      ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES.key(object[:itf_type_cd])
    end

    def creation_date
      object[:create_dt]
    end

    def expiration_date
      object[:exprtn_dt]
    end

    def status
      object[:itf_status_type_cd]&.downcase
    end
  end
end
