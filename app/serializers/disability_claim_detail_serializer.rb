# frozen_string_literal: true
class DisabilityClaimDetailSerializer < DisabilityClaimBaseSerializer
  attributes :contention_list, :va_representative

  def contention_list
    object.data['contentionList']
  end

  def va_representative
    object.data['poa']
  end
end
