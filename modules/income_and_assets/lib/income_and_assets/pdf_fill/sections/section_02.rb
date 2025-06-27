# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section II: Claimant Information
    class Section2 < Section
      # Section configuration hash
      #
      # NOTE: `key` fields should follow the format:
      #   `<key_prefix><subprefix>.<key>`
      # Example: 'Section2A.ClaimantnName.First'
      #
      KEY = {
        # 2A
        'claimantFullName' => {
          # form allows up to 39 characters but validation limits to 30,
          # so no overflow is needed
          'first' => {
            key: generate_key('A', 'ClaimantName.First')
          },
          'middle' => {
            key: generate_key('A', 'ClaimantName.MI')
          },
          # form allows up to 34 characters but validation limits to 30,
          # so no overflow is needed
          'last' => {
            key: generate_key('A', 'ClaimantName.Last')
          }
        },
        # 2B
        'claimantSocialSecurityNumber' => {
          key: generate_key('B', 'ClaimantsSSN')
        },
        # 2C
        'claimantPhone' => {
          key: generate_key('C', 'ClaimantTelephoneNumber')
        },
        # 2D
        'claimantType' => {
          key: generate_key('D', 'TypeofClaimant')
        },
        # 2E
        'incomeNetWorthDateRange' => {
          'from' => {
            key: generate_key('E', 'DateStarting')
          },
          'to' => {
            key: generate_key('E', 'DateEnding')
          },
          'useDateReceivedByVA' => {
            key: generate_key('E', 'DateReceivedByVA')
          }
        }
      }.freeze

      ##
      # Expands the claimants's information by extracting and capitalizing the first letter of the middle name.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        claimant_middle_name = form_data['claimantFullName'].try(:[], 'middle')
        claimant_type = form_data['claimantType']
        net_worth_date_range = form_data['incomeNetWorthDateRange']

        form_data['claimantFullName']['middle'] = claimant_middle_name[0].upcase if claimant_middle_name.present?

        form_data['claimantType'] = IncomeAndAssets::Constants::CLAIMANT_TYPES[claimant_type]

        if net_worth_date_range.blank? || net_worth_date_range['from'].blank? || net_worth_date_range['to'].blank?
          form_data['incomeNetWorthDateRange'] = {
            'from' => nil,
            'to' => nil,
            'useDateReceivedByVA' => true
          }
        else
          form_data['incomeNetWorthDateRange'] = {
            'from' => format_date_to_mm_dd_yyyy(net_worth_date_range['from']),
            'to' => format_date_to_mm_dd_yyyy(net_worth_date_range['to']),
            'useDateReceivedByVA' => false
          }
        end
      end
    end
  end
end
