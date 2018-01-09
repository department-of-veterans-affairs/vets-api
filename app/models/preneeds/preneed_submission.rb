# frozen_string_literal: true

module Preneeds
  class PreneedSubmission < ActiveRecord::Base
    validates :tracking_number, :return_description, presence: true
    validates :tracking_number, :application_uuid, uniqueness: true
  end
end
