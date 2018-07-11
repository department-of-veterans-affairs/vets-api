# frozen_string_literal: true

EMISPolicy = Struct.new(:user, :emis) do
  def access?
    if user.edipi.present?
      StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.edipi", tags: ['present:true'])
      true
    else
      StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.edipi", tags: ['present:false'])
      false
    end
  end
end
