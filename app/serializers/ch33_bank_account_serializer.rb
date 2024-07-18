# frozen_string_literal: true

class Ch33BankAccountSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :hashes

  attribute :account_type do |object|
    next nil if object[:dposit_acnt_type_nm].blank?

    object[:dposit_acnt_type_nm] == 'C' ? 'Checking' : 'Savings'
  end

  attribute :account_number do |object|
    StringHelpers.mask_sensitive(object[:dposit_acnt_nbr])
  end

  attribute :financial_institution_routing_number do |object|
    StringHelpers.mask_sensitive(object[:routng_trnsit_nbr])
  end

  attribute :financial_institution_name do |object|
    object[:financial_institution_name]
  end
end
