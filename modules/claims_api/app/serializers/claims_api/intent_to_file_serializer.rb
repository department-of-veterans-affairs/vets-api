# frozen_string_literal: true

module ClaimsApi
  class IntentToFileSerializer
    include JSONAPI::Serializer

    set_type :intent_to_file

    set_id do |object|
      object[:intent_to_file_id]
    end

    attribute :creation_date do |object|
      object[:create_dt]
    end

    attribute :expiration_date do |object|
      object[:exprtn_dt]
    end

    attribute :type do |object|
      ClaimsApi::IntentToFile::ITF_TYPES_TO_BGS_TYPES.key(object[:itf_type_cd])
    end

    attribute :status do |object|
      object[:itf_status_type_cd]&.downcase
    end
  end
end
