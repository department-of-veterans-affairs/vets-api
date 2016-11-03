# frozen_string_literal: true
class DisabilityClaimListSerializer < DisabilityClaimBaseSerializer
  def phase
    phase_from_keys 'status'
  end

  private

  def object_data
    object.list_data
  end
end
