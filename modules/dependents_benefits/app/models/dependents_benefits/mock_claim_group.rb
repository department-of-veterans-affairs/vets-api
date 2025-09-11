# frozen_string_literal: true

module DependentsBenefits
  ##
  # Skeleton ClaimGroup class - simulates model interface until database implementation
  # Groups related 686c/674 claims for coordinated submission tracking
  #
  class MockClaimGroup
    attr_accessor :status, :parent_claim_id, :claim_id, :id, :user_data
    attr_reader :created_at, :updated_at

    def initialize(parent_claim_id:, claim_id:, status: 'PENDING', id: SecureRandom.uuid)
      @parent_claim_id = parent_claim_id
      @claim_id = claim_id
      @status = status
      @id = id
      @user_data = {}
      @created_at = @updated_at = Time.current
    end

    def update!(attributes)
      attributes.each { |key, value| send("#{key}=", value) if respond_to?("#{key}=") }
      @updated_at = Time.current
      true
    end

    # Simulate ActiveRecord interface
    def save!
      true
    end

    def reload
      self
    end

    # Simulate ActiveRecord advisory lock interface
    # In real implementation, this would acquire database advisory lock
    def with_lock
      yield if block_given?
    end

    def parent_claim = @parent_claim ||= DependentsBenefits::SavedClaim.find(parent_claim_id)
    def claim = @claim ||= DependentsBenefits::SavedClaim.find(claim_id)
    def parent_claim? = parent_claim_id == claim_id

    def mark_succeeded_and_notify!
      return false if status == 'SUCCEEDED'

      update!(status: 'SUCCEEDED')
      Rails.logger.info("ClaimGroup #{parent_claim_id} succeeded - email logic to be implemented") if parent_claim?
      true
    end

    def mark_failed_and_notify!
      return false if status == 'FAILED'

      update!(status: 'FAILED')
      Rails.logger.info("ClaimGroup #{parent_claim_id} failed - email logic to be implemented") if parent_claim?
      true
    end

    def sibling_groups = []
    def all_siblings_succeeded? = sibling_groups.all? { |group| group.status == 'SUCCEEDED' }
  end
end
