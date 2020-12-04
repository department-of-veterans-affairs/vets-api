# frozen_string_literal: true

require 'attr_encrypted'
require 'common/models/redis_store'

module Form1010cg
  class SubmissionStore < Common::RedisStore
    # TODO: Add encrypted attr :form_json
    redis_store REDIS_CONFIG[:form1010cg_submissions][:namespace]
    redis_ttl REDIS_CONFIG[:form1010cg_submissions][:each_ttl]
    redis_key :claim_guid

    attribute :claim_guid
    attribute :carma_case_id
    attribute :submitted_at
    attribute :claim_json
    attribute :metadata_json

    validates :claim_guid, presence: true
    validates :carma_case_id, presence: true
    validates :claim_json, presence: true
    validates :metadata_json, presence: true

    validate :claim_is_valid
    validate :metadata_is_valid_json

    def claim
      SavedClaim::CaregiversAssistanceClaim.new(JSON.parse(claim_json)) if claim_json&.length
    end

    def claim=(value)
      self.claim_json = value.is_a?(SavedClaim::CaregiversAssistanceClaim) ? value.to_json : nil
    end

    def metadata
      JSON.parse(metadata_json) if metadata_json&.length
    end

    private

    def claim_is_valid
      errors.add(:claim_json) unless claim.valid?
    end

    def metadata_is_valid_json
      JSON.parse(metadata_json)
    rescue JSON::ParserError
      # TODO: pass error message?
      errors.add(:metadata_json)
    end
  end
end

# class SavedClaimJson < ActiveRecord::Type::String
#   # def cast(value)
#   #   if !value.kind_of?(SavedClaim)
#   #     super(
#   #       value.to_json(
#   #         except: value.class.encrypted_attributes.keys
#   #       )
#   #     )
#   #   else
#   #     super
#   #   end
#   # end

#   def serialize(value)
#     case value
#     when SavedClaim
#       return value.to_json(except: value.class.encrypted_attributes.keys)
#     else
#       value
#     end
#   end

#   def deserialize(value)
#     case value
#     when String
#       return SavedClaim::CaregiversAssistanceClaim.new(JSON.parse(value))
#     else
#       value
#     end
#   end
# end

# # class JsonAttrSerializer
# #   attr_reader :symbolize_names

# #   def initialize(symbolize_names: false)
# #     @symbolize_names = symbolize_names
# #   end

# #   def load(value)
# #     JSON.parse(value, symbolize_names: @symbolize_names)
# #   end

# #   def dump(value, keys_casting)
# #     value.to_json
# #   end
# # end

# class SavedClaimJson < Virtus::Attribute
#   def coerce(value)
#     case value
#     when SavedClaim
#       value.to_json(except: value.class.encrypted_attributes.keys)
#     when String
#       value
#     else
#       nil
#     end
#   end
# end

# ActiveRecord::Type.register(:saved_claim_json, SavedClaimJson)
