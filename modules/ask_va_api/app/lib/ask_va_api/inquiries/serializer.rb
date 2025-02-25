# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class Serializer
      include JSONAPI::Serializer
      set_type :inquiry

      attributes :inquiry_number,
                 :allow_attachments,
                 :allow_replies,
                 :has_attachments,
                 :attachments,
                 :category_name,
                 :created_on,
                 :correspondences,
                 :has_been_split,
                 :inquiry_topic,
                 :level_of_authentication,
                 :last_update,
                 :queue_id,
                 :queue_name,
                 :status,
                 :submitter_question,
                 :school_facility_code,
                 :veteran_relationship

      attribute :correspondences do |obj|
        if obj.correspondences.blank?
          obj.correspondences
        else
          AskVAApi::Correspondences::Serializer.new(obj.correspondences).serializable_hash
        end
      end
    end
  end
end
