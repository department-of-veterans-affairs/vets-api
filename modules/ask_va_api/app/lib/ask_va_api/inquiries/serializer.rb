# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class Serializer
      include JSONAPI::Serializer
      set_type :inquiry

      attributes :inquiry_number,
                 :attachments,
                 :correspondences,
                 :has_attachments,
                 :has_been_split,
                 :level_of_authentication,
                 :last_update,
                 :status,
                 :submitter_question,
                 :school_facility_code,
                 :topic,
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
