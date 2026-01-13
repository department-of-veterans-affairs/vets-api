# frozen_string_literal: true

module DependentsBenefits
  module ClaimBehavior
    ##
    # Methods for extracting and handling veteran information from forms
    #
    module VeteranInformation
      extend ActiveSupport::Concern

      # Adds veteran information to the parsed form
      #
      # Merges the provided user data (containing veteran information) into the
      # claim's parsed form, modifying it in place
      #
      # @param user_data [Hash] Hash containing veteran information to merge
      # @return [Hash] The updated parsed form with veteran information merged
      def add_veteran_info(user_data)
        parsed_form.merge!(user_data)
      end

      # Generates a folder identifier string for organizing veteran claims
      #
      # Creates an identifier starting with 'VETERAN' and appends the first available
      # identifier from SSN, participant_id, or ICN in that order of priority
      #
      # @return [String] Folder identifier in format 'VETERAN' or 'VETERAN:TYPE:VALUE'
      # @example
      #   folder_identifier #=> "VETERAN:SSN:123456789"
      #   folder_identifier #=> "VETERAN:ICN:1234567890V123456"
      def folder_identifier
        fid = 'VETERAN'
        { ssn:, participant_id:, icn: }.each do |k, v|
          if v.present?
            fid += ":#{k.to_s.upcase}:#{v}"
            break
          end
        end

        fid
      end

      private

      # Extracts the veteran's Social Security Number from the parsed form
      #
      # @return [String, nil] The veteran's SSN or nil if not present
      def ssn
        parsed_form&.dig('veteran_information', 'ssn')
      end

      # Extracts the veteran's participant ID from the parsed form
      #
      # @return [String, nil] The veteran's participant ID or nil if not present
      def participant_id
        parsed_form&.dig('veteran_information', 'participant_id')
      end

      # Extracts the veteran's Integration Control Number (ICN) from the parsed form
      #
      # @return [String, nil] The veteran's ICN or nil if not present
      def icn
        parsed_form&.dig('veteran_information', 'icn')
      end
    end
  end
end
