# frozen_string_literal: true

class Ch33BankAccountSerializer < ActiveModel::Serializer
  attributes :account_type, :account_number, :financial_institution_routing_number, :financial_institution_name

  def account_type
    dposit_acnt_type_nm = object[:dposit_acnt_type_nm]

    if dposit_acnt_type_nm.present?
      dposit_acnt_type_nm == 'C' ? 'Checking' : 'Savings'
    end
  end

  def account_number
    StringHelpers.mask_sensitive(object[:dposit_acnt_nbr])
  end

  def financial_institution_routing_number
    StringHelpers.mask_sensitive(object[:routng_trnsit_nbr])
  end

  def financial_institution_name
    object[:financial_institution_name]
  end

  def id
    nil
  end
end
