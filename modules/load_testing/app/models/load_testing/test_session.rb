module LoadTesting
  class TestSession < ApplicationRecord
    validates :status, presence: true
    validates :concurrent_users, presence: true
    validates :configuration, presence: true

    validate :validate_configuration_format
    
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

    private

    def validate_configuration_format
      return if configuration.blank?

      unless configuration['client_id'].present?
        errors.add(:configuration, 'must include client_id')
      end

      unless configuration['type'].present?
        errors.add(:configuration, 'must include type')
      end

      unless configuration['stages'].is_a?(Array)
        errors.add(:configuration, 'must include stages array')
      end

      configuration['stages']&.each do |stage|
        unless stage['duration'].present? && stage['target'].present?
          errors.add(:configuration, 'each stage must include duration and target')
        end
      end
    end
  end
end 