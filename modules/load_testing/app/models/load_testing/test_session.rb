module LoadTesting
  class TestSession < ApplicationRecord
    validates :status, presence: true
    validates :concurrent_users, presence: true
    
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
  end
end 