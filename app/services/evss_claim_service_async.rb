# frozen_string_literal: true

class EVSSClaimServiceAsync
  include SentryLogging

  def initialize(user)
    @user = user
    @tracker = EVSSClaimsSyncStatusTracker.new(user_uuid: user.uuid)
  end

  def all
    status = @tracker.get_collection_status
    unless status
      @tracker.set_collection_status('REQUESTED')
      EVSS::RetrieveClaimsFromRemoteJob.perform_async(@user.uuid)
      status = 'REQUESTED'
    end
    [claims_scope.all, status]
  end

  def update_from_remote(claim)
    @tracker.claim_id = claim.id
    status = @tracker.get_single_status
    unless status
      status = 'REQUESTED'
      @tracker.set_single_status('REQUESTED')
      EVSS::UpdateClaimFromRemoteJob.perform_async(@user.uuid, claim.id)
    end
    [claim, status]
  end

  def claims_scope
    EVSSClaim.for_user(@user)
  end
end
