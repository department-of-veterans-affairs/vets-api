# frozen_string_literal: true

require 'common/models/base'
require 'preneeds/xml_date'

module Preneeds
  # Models the input needed to query {Preneeds::Service#get_military_rank_for_branch_of_service}
  # For use within the {Preneeds::BurialForm} form.
  #
  # @!attribute branch_of_service
  #   @return [String] branch of service abbreviated code
  # @!attribute start_date
  #   @return [XmlDate] start date for branch of service
  # @!attribute end_date
  #   @return [XmlDate] end date of branch of service.
  #
  class MilitaryRankInput < Preneeds::Base
    include ActiveModel::Validations

    attr_accessor :branch_of_service, :start_date, :end_date

    # Some branches have no end_date, but api requires it just the same
    validates :start_date, :end_date, presence: true, format: /\A\d{4}-\d{2}-\d{2}\z/
    validates :branch_of_service, format: /\A\w{2}\z/

  end
end
