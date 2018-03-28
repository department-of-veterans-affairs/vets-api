# frozen_string_literal: true

class PensionBurialNotifications
  include Sidekiq::Worker

  ENABLED_DATE = '2018-01-01'.to_date # TODO: Update once form is live
  QUERY_STATUSES = [nil, 'in process'].freeze
  FORM_IDS = ['21P-527EZ', '21P-530'].freeze

  def perform
    claims = {}
    SavedClaim.where(
      form_id: FORM_IDS,
      status: QUERY_STATUSES,
      created_at: ENABLED_DATE.beginning_of_day..Time.zone.now
    ).find_each { |c| claims[c.guid] = c }

    claim_uuids = claims.keys

    claim_uuids.each_slice(100) do |uuid_batch|
      get_status(uuid_batch).each do |status|
        uuid = status['uuid']
        claim = claims[uuid]

        old_status = claim.status&.downcase
        new_status = status['status'].downcase

        if new_status != old_status
          # Status has changed, perform follow up actions
          #
          # case new_status
          # when 'received' # received by ICMHS
          # when 'in process' # being processed by ICMHS
          # when 'success' # received by DMHS
          # when 'error' # check 'errorMessage' field of status object
          # end

          claim.status = new_status
          claim.save!
        end
      end
    end
  end

  private

  def get_status(uuids)
    response = PensionBurial::Service.new.status(uuids)
    JSON.parse(response.body).flatten
  end
end
