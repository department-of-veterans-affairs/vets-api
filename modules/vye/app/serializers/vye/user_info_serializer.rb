# frozen_string_literal: true

module Vye
  class UserInfoSerializer
    def initialize(resource)
      @resource = resource
    end

    def to_json(*)
      Oj.dump(serializable_hash, mode: :compat, time_format: :ruby)
    end

    def serializable_hash
      {
        'vye/user_info': {
          rem_ent: @resource.rem_ent,
          cert_issue_date: @resource.cert_issue_date,
          del_date: @resource.del_date,
          date_last_certified: @resource.date_last_certified,
          payment_amt: @resource.payment_amt,
          indicator: @resource.indicator,
          zip_code: @resource.zip_code,
          latest_address: serialized_latest_address,
          pending_documents: serialized_pending_documents,
          verifications: serialized_verifications,
          pending_verifications: serialized_pending_verifications
        }
      }
    end

    private

    def serialized_latest_address
      Vye::AddressChangeSerializer.new(@resource.latest_address).serializable_hash
    end

    def serialized_pending_documents
      @resource.pending_documents.map do |pending_document|
        Vye::PendingDocumentSerializer.new(pending_document).serializable_hash
      end
    end

    def serialized_verifications
      @resource.verifications.map do |verification|
        Vye::VerificationSerializer.new(verification).serializable_hash
      end
    end

    def serialized_pending_verifications
      @resource.pending_verifications.map do |pending_verification|
        Vye::VerificationSerializer.new(pending_verification).serializable_hash
      end
    end
  end
end
