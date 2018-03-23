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
      old = claim.status.downcase
      new = statuses[uuid]['status'].downcase

      if new != old
        # Do things!

        claim.status = new
        claim.save!
      end
    end
  end

  private

  def get_statuses(uuids)
    service = PensionBurial::Service.new
    response = service.status(uuids)
    results = JSON.parse(response.body)

    results.each_with_object({}) do |row, statuses|
      row.each do |result|
        uuid = result['uuid']
        statuses[uuid] = result
      end

      statuses
    end
  end
end
