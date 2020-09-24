# frozen_string_literal: true

class EVSSClaimServiceAsync
  include SentryLogging

  def initialize(user)
    @user = user
    @tracker = EVSSClaimsSyncStatusTracker.find_or_build(user.uuid)
  end

  def all
    status = @tracker.get_collection_status
    unless status
      status = 'REQUESTED'
      @tracker.set_collection_status(status)
      EVSS::RetrieveClaimsFromRemoteJob.perform_async(@user.uuid)
    end
    claims = status == 'REQUESTED' ? [] : claims_scope.all
    @tracker.delete_collection_status unless status == 'REQUESTED'
    [claims, status]
  end

  def update_from_remote(claim)
    @tracker.claim_id = claim.id
    status = @tracker.get_single_status
    unless status
      status = 'REQUESTED'
      @tracker.set_single_status(status)
      EVSS::UpdateClaimFromRemoteJob.perform_async(@user.uuid, claim.id)
    end
    @tracker.delete_single_status unless status == 'REQUESTED'
    [claim, status]
  end

  def claims_scope
    EVSSClaim.for_user(@user)
  end
end
