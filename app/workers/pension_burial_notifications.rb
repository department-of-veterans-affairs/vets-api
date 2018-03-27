# frozen_string_literal: true

class PensionBurialNotifications
  include Sidekiq::Worker

  ENABLED_DATE = '2018-01-01'.to_date # TODO Update once form is live
  FORM_IDS = ['21P-527EZ', '21P-530'].freeze

  def perform
    claims = {}
    SavedClaim.where(
      form_id: FORM_IDS,
      status: [nil, 'in process'],
      created_at: ENABLED_DATE..Time.zone.now
    ).find_each { |c| claims[c.guid] = c }

    claim_uuids = claims.keys

    get_status(claim_uuids).each do |status|
      uuid = status['uuid']
      claim = claims[uuid]

      old_status = claim.status.downcase
      new_status = status['status'].downcase

      if new_status != old_status
        claim.status = new_status
        claim.save!
      end
    end
  end

  private

  def get_status(uuids)
    response = PensionBurial::Service.new.status(uuids)
    JSON.parse(response.body).flatten
  end
end
