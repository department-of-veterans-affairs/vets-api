class SessionActivity < ActiveRecord::Base
  after_initialize :initialize_defaults

  private

  def initialize_defaults
    self.originating_request_id ||= Thread.current['originating_request_id'] || Thread.current['request_id']
    self.status ||= 'abandoned'
  end
end
