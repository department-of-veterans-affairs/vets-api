# frozen_string_literal: true

class Notification < ApplicationRecord
  include Notifications::EnumSubjectValues
  include Notifications::EnumStatusValues

  belongs_to :account

  validates :subject, :account_id, presence: true

  # @see https://api.rubyonrails.org/v5.2/classes/ActiveRecord/Enum.html
  #
  enum subject: subjects_mapped_to_database_integers
  enum status: statuses_mapped_to_database_integers
end
