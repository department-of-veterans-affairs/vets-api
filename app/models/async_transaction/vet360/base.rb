# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class Base < AsyncTransaction::Base
      FINAL_STATUSES = %w[
        REJECTED
        COMPLETED_SUCCESS
        COMPLETED_NO_CHANGES_DETECTED
        COMPLETED_FAILURE
      ].freeze
      REQUESTED = 'requested'
      COMPLETED = 'completed'

      scope :for_user, ->(user) { where(user_uuid: user.uuid) }
      scope :last_requested, -> { where(status: Base::REQUESTED).order(created_at: :desc).limit(1) }

      validates :source_id, presence: true, unless: :initialize_person?

      # Creates an initial AsyncTransaction record for ongoing tracking
      #
      # @param user [User] The user associated with the transaction
      # @param response [VAProfile::ContactInformation::TransactionResponse] An instance of
      #   a VAProfile::ContactInformation::TransactionResponse class, be it Email, Address, etc.
      # @return [AsyncTransaction::Vet360::Base] A AsyncTransaction::Vet360::Base record, be it Email, Address, etc.
      #
      def self.start(user, response)
        create(
          user_uuid: user.uuid,
          user_account: user.user_account,
          source_id: user.vet360_id,
          source: 'vet360',
          status: REQUESTED,
          transaction_id: response.transaction.id,
          transaction_status: response.transaction.status,
          metadata: response.transaction.messages
        )
      end

      # Updates the status and transaction_status with fresh API data
      # @param user [User] the user whose tx data is being updated
      # @param service [VAProfile::ContactInformation::Service] an initialized vet360 client
      # @param tx_id [int] the transaction_id
      # @return [AsyncTransaction::Vet360::Base]
      def self.refresh_transaction_status(user, service, tx_id = nil)
        transaction_record = find_transaction!(user.uuid, tx_id)
        return transaction_record if transaction_record.finished?

        api_response = Base.fetch_transaction(transaction_record, service)
        update_transaction_from_api(transaction_record, api_response)
      end

      # Requests a transaction from vet360 for an app transaction
      # @param user [User] the user whose tx data is being updated
      # @param transaction_record [AsyncTransaction::Vet360::Base] the tx record to be checked
      # @param service [VAProfile::ContactInformation::Service] an initialized vet360 client
      # @return [VAProfile::Models::Transaction]
      def self.fetch_transaction(transaction_record, service)
        case transaction_record
        when AsyncTransaction::Vet360::AddressTransaction
          service.get_address_transaction_status(transaction_record.transaction_id)
        when AsyncTransaction::Vet360::EmailTransaction
          service.get_email_transaction_status(transaction_record.transaction_id)
        when AsyncTransaction::Vet360::TelephoneTransaction
          service.get_telephone_transaction_status(transaction_record.transaction_id)
        when AsyncTransaction::Vet360::PermissionTransaction
          service.get_permission_transaction_status(transaction_record.transaction_id)
        when AsyncTransaction::Vet360::InitializePersonTransaction
          service.get_person_transaction_status(transaction_record.transaction_id)
        else
          # Unexpected transaction type means something went sideways
          raise
        end
      end

      # Finds a transaction by transaction_id for a user
      # @param user_uuid [String] the user's UUID
      # @param transaction_id [String] the transaction UUID
      # @return [AddressTransaction, EmailTransaction, TelephoneTransaction]
      def self.find_transaction!(user_uuid, transaction_id)
        Base.find_by!(user_uuid:, transaction_id:)
      end

      def self.update_transaction_from_api(transaction_record, api_response)
        transaction_record.status = COMPLETED if FINAL_STATUSES.include? api_response.transaction.status
        transaction_record.transaction_status = api_response.transaction.status
        transaction_record.metadata = api_response.transaction.messages
        transaction_record.save!
        transaction_record
      end

      # Returns true or false if a transaction is "over"
      # @return [Boolean] true if status is "over"
      # @note this checks transaction_status status fields, which should be redundant
      def finished?
        FINAL_STATUSES.include?(transaction_status) || status == COMPLETED
      end

      # Wrapper for .refresh_transaction_status which finds any outstanding transactions
      #   for a user and refreshes them
      # @param user [User] the user whose transactions we're checking
      # @param service [VAProfile::ContactInformation::Service] an initialized vet360 client
      # @return [Array] An array with any outstanding transactions refreshed. Empty if none.
      def self.refresh_transaction_statuses(user, service)
        last_ongoing_transactions_for_user(user).each_with_object([]) do |transaction, array|
          array << refresh_transaction_status(
            user,
            service,
            transaction.transaction_id
          )
        end
      end

      # Find the most recent address, email, or telelphone transactions for a user
      # @praram user [User] the user whose transactions we're finding
      # @return [Array] an array of any outstanding transactions
      def self.last_ongoing_transactions_for_user(user)
        ongoing_transactions = []
        ongoing_transactions += AddressTransaction.last_requested.for_user(user)
        ongoing_transactions += EmailTransaction.last_requested.for_user(user)
        ongoing_transactions += TelephoneTransaction.last_requested.for_user(user)
        ongoing_transactions += PermissionTransaction.last_requested.for_user(user)
        ongoing_transactions
      end

      private

      def initialize_person?
        type&.constantize == AsyncTransaction::Vet360::InitializePersonTransaction
      end
    end
  end
end
