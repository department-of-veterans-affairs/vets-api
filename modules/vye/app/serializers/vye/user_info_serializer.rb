# frozen_string_literal: true

module Vye
  class UserInfoSerializer < ActiveModel::Serializer
    attributes :suffix,
               :full_name,
               :address_line2,
               :address_line3,
               :address_line4,
               :address_line5,
               :address_line6,
               :zip,
               :rem_ent,
               :cert_issue_date,
               :del_date,
               :date_last_certified,
               :payment_amt,
               :indicator

    has_many :awards, serializer: Vye::AwardSerializer
    has_many :pending_documents, serializer: Vye::PendingDocumentSerializer
    has_many :verifications, serializer: Vye::VerificationSerializer
  end
end
