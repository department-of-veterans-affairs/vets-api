# frozen_string_literal: true

class PensionBurialNotifications
  include Sidekiq::Worker

  FORM_IDS = ['21P-527EZ', '21P-530'].freeze

  def perform
    claims = {}

    SavedClaim.where(
      form_id: FORM_IDS,
      status: [nil, 'in process']
    ).find_each { |c| claims[c.guid] = c }

    statuses = get_statuses(claims.keys)

    claims.each do |uuid, claim|
      old_status = claim.status.downcase
      new_status = statuses[uuid]['status'].downcase

      if new_status != old_status
        claim.status = new_status
        claim.save!
      end
    end
  end

  private

  def get_statuses(uuids)
    response = PensionBurial::Service.new.status(uuids)

    JSON.parse(response.body).each_with_object({}) do |row, statuses|
      row.each do |result|
        uuid = result['uuid']
        statuses[uuid] = result
      end

      statuses
    end
  end
end
