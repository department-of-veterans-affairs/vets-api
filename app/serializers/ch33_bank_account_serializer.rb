# frozen_string_literal: true

class Ch33BankAccountSerializer < ActiveModel::Serializer
  attributes :account_type, :account_number, :financial_institution_routing_number

  def account_type
    dposit_acnt_type_nm = find_ch33_dd_eft_response[:dposit_acnt_type_nm]

    if dposit_acnt_type_nm.present?
      dposit_acnt_type_nm == 'C' ? 'Checking' : 'Savings'
    end
  end

  def account_number
    StringHelpers.mask_sensitive(find_ch33_dd_eft_response[:dposit_acnt_nbr])
  end

  def financial_institution_routing_number
    StringHelpers.mask_sensitive(find_ch33_dd_eft_response[:routng_trnsit_nbr])
  end

  def id
    nil
  end

  private

  def find_ch33_dd_eft_response
    @find_ch33_dd_eft_response ||= object.body[:find_ch33_dd_eft_response][:return]
  end
end
