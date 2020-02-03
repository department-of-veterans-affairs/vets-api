# frozen_string_literal: true

require 'common/client/base'

module MDOT
  ##
  # Medical Devices Ordering Tool
  #
  # This service integrates with the DLC API and allows veterans
  # to reorder medical devices such as hearing aid batteries.
  #

  class Client < Common::Client::Base
    configuration MDOT::Configuration

    def initialize(current_user)
      @user = current_user
    end

    ##
    # GETs medical supplies available for reorder for veteran.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    # def get_supplies
    # end

    ##
    # POSTs to DLC endpoint to create a new order.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    # def submit_order
    # end

    ##
    # GETS veterans contact information.
    #
    # @return Hash of veteran information.
    def get_veteran_information
      veteran_information
    end

    ##
    # PUTS (modifies) veterans contact information.
    #
    # @return Hash of success or failure.
    # def modify_veteran_information
    # end

    private

    def veteran_information
      {
        first_name: @user.first_name,
        last_name: @user.last_name,
        birth_date: @user.birth_date,
        gender: @user.gender,
        email: @user.email
        
      }
    end
  end
end
