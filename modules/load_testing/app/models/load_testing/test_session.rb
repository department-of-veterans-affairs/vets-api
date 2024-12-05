module LoadTesting
  class TestSession < ApplicationRecord
    validates :status, presence: true
    validates :concurrent_users, presence: true
    validates :configuration, presence: true
    
    has_many :test_tokens, class_name: 'LoadTesting::TestToken', dependent: :destroy
    
    enum status: {
      pending: 'pending',
      running: 'running',
      completed: 'completed',
      failed: 'failed'
    }

    def self.active
      where(status: ['pending', 'running'])
    end

    after_initialize do |test_session|
      Rails.logger.info "TestSession initialized with configuration: #{test_session.configuration.inspect}"
    end
  end
end 