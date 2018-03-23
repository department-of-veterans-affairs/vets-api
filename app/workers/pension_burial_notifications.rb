# frozen_string_literal: true

class PensionBurialNotifications
  include Sidekiq::Worker

  def perform
    service = PensionBurial::Service.new
    guids = SavedClaim.where(
      form_id: ['21P-527EZ', '21P-530'],
      claim_status: [nil, 'In Process']
    ).find_each.map(&:guid)

    binding.pry
  end
end
