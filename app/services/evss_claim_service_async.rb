# frozen_string_literal: true

class EVSSClaimServiceAsync
  include SentryLogging

  def initialize(user)
    @user = user
    @cacher = EVSSClaimsRedisHelper.new(user_uuid: user.uuid)
  end

  def all
    cached_res = @cacher.find_collection
    if cached_res
      status = cached_res[:response][:status]
    else
      @cacher.cache_collection(data: [], status: 'REQUESTED')
      EVSS::RetrieveClaimsForUserJob.perform_async(@user.uuid)
      status = 'REQUESTED'
    end
    [claims_scope.all, status]
  end

  def update_from_remote(claim)
    @cacher.claim_id = claim.id
    cached_res = @cacher.find_one
    if cached_res
      status = cached_res[:response][:status]
    else
      status = 'REQUESTED'
      @cacher.cache_one(status: 'REQUESTED')
      EVSS::UpdateClaimFromRemoteJob.perform_async(@user.uuid, claim.id)
    end
    [claim, status]
  end

  def claims_scope
    EVSSClaim.for_user(@user)
  end
end
