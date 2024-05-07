# frozen_string_literal: true

module Vye
  class UserInfoSerializer < ActiveModel::Serializer
    attributes(
      :rem_ent,
      :cert_issue_date,
      :del_date,
      :date_last_certified,
      :payment_amt,
      :indicator
    )

    has_many :address_changes, serializer: Vye::AddressChangeSerializer
    has_many :pending_documents, serializer: Vye::PendingDocumentSerializer
    has_many :verifications, serializer: Vye::VerificationSerializer
    has_many :pending_verifications, serializer: Vye::VerificationSerializer
  end
end
