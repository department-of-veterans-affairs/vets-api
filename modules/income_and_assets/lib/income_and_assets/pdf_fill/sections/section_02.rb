# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section II: Claimant Informations
    class Section2 < Section
      # Section configuration hash
      KEY = {
        # 2a
        'claimantFullName' => {
          # form allows up to 39 characters but validation limits to 30,
          # so no overflow is needed
          'first' => {
            key: 'F[0].Page_4[0].ClaimantsName.First[0]'
          },
          'middle' => {
            key: 'F[0].Page_4[0].ClaimantsName.MI[0]'
          },
          # form allows up to 34 characters but validation limits to 30,
          # so no overflow is needed
          'last' => {
            key: 'F[0].Page_4[0].ClaimantsName.Last[0]'
          }
        },
        # 2b
        'claimantSocialSecurityNumber' => {
          key: 'F[0].Page_4[0].ClaimantsSSN[0]'
        },
        # 2c
        'claimantPhone' => {
          key: 'F[0].Page_4[0].ClaimantTelephoneNumber[0]'
        },
        # 2d
        'claimantType' => {
          key: 'F[0].Page_4[0].TypeofClaimant[0]'
        },
        # 2e
        'incomeNetWorthDateRange' => {
          'from' => {
            key: 'F[0].Page_4[0].DateStarting[0]'
          },
          'to' => {
            key: 'F[0].Page_4[0].DateEnding[0]'
          },
          'useDateReceivedByVA' => {
            key: 'F[0].Page_4[0].DateReceivedByVA[0]'
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
