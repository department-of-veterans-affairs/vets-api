# frozen_string_literal: true

EMISPolicy = Struct.new(:user, :emis) do
  def access?
    if user.edipi.present?
      StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.edipi", tags: ['success'])
      true
    else
      StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.edipi", tags: ['failure'])
      false
    end
  end
end
