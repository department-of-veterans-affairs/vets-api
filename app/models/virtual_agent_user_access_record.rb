# frozen_string_literal: true

class VirtualAgentUserAccessRecord < ApplicationRecord
  validates :id, :action_type, :first_name, :last_name, :ssn, :icn, presence: true
end
