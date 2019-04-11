# frozen_string_literal: true

module Preneeds
  # A record to track a {Preneeds::BurialForm} form submission.
  #
  # @!attribute id
  #   @return [Integer] auto-increment primary key.
  # @!attribute tracking_number
  #   @return (see Preneeds::ReceiveApplication#tracking_number)
  # @!attribute application_uuid
  #   @return (see Preneeds::ReceiveApplication#application_uuid)
  # @!attribute return_description
  #   @return (see Preneeds::ReceiveApplication#return_description)
  # @!attribute return_code
  #   @return (see Preneeds::ReceiveApplication#return_code)
  # @!attribute created_at
  #   @return [Timestamp] created at date.
  # @!attribute updated_at
  #   @return [Timestamp] updated at date.
  #
  class PreneedSubmission < ApplicationRecord
    validates :tracking_number, :return_description, presence: true
    validates :tracking_number, :application_uuid, uniqueness: true
  end
end
