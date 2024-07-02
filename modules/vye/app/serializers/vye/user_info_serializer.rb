# frozen_string_literal: true

module Vye
  class UserInfoSerializer
    include JSONAPI::Serializer

    attributes :rem_ent, :cert_issue_date, :del_date, :date_last_certified,
               :payment_amt, :indicator

    attribute :zip_code do |object, params|
      object.zip_code if params[:api_key]
    end

    has_one :latest_address, serializer: Vye::AddressChangeSerializer
    has_many :pending_documents, serializer: Vye::PendingDocumentSerializer, &:pending_documents
    has_many :verifications, serializer: Vye::VerificationSerializer, &:verifications
    has_many :pending_verifications, serializer: Vye::VerificationSerializer, &:pending_verifications
  end
end
