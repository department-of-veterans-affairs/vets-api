# frozen_string_literal: true

require 'inherited_proofing/mhv/service'
require 'inherited_proofing/errors'

module InheritedProofing
  module MHV
    class InheritedProofingVerifier
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def perform
        raise InheritedProofing::Errors::IdentityDocumentMissingError if missing_identity_doc?

        cache_identity_data
        code
      end

      private

      def correlation_id
        @correlation_id ||= begin
          return user.mhv_correlation_id if user.mhv_correlation_id.present?

          correlation_hsh = InheritedProofing::MHV::Service.get_correlation_data(user.icn)
          correlation_hsh['correlationId']
        end
      end

      def identity_info
        @identity_info ||= begin
          return {} if correlation_id.blank?

          InheritedProofing::MHV::Service.get_verification_data(correlation_id)
        end
      end

      def cache_identity_data
        InheritedProofing::MHVIdentityData.new(user_uuid: user.uuid, code:, data: identity_info).save!
        InheritedProofing::AuditData.new(user_uuid: user.uuid, code:, legacy_csp: 'mhv').save!
      end

      def missing_identity_doc?
        identity_info['identityDocumentExist'].blank?
      end

      def code
        @code ||= SecureRandom.hex
      end
    end
  end
end
