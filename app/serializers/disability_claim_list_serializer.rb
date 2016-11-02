# frozen_string_literal: true
class DisabilityClaimListSerializer < DisabilityClaimBaseSerializer
  private

  def object_data
    object.list_data
  end
end
