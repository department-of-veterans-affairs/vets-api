# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section11
  ##
  # Section XI
  # Build claimant direct deposit structured data entries.
  #
  # @param account [Hash]
  def merge_claimant_direct_deposit_fields(account)
    return unless account.is_a?(Hash)

    fields.merge!(
      {
        'NAME_FINANCIAL_INSTITUTE' => account['bankName'],
        'ROUTING_TRANSIT_NUMBER' => account['routingNumber'],
        'CHECKING_ACCOUNT_CB' => account['accountType'] == 'CHECKING',
        'SAVINGS_ACCOUNT_CB' => account['accountType'] == 'SAVINGS',
        'NO_ACCOUNT_CB' => account['accountType'] == 'NO_ACCOUNT',
        'AccountNumber' => account['accountNumber']
      }
    )
  end
end
