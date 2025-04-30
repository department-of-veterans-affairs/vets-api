# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'income_and_assets/constants'
require 'income_and_assets/helpers'
require 'income_and_assets/pdf_fill/sections/section_03'
require 'income_and_assets/pdf_fill/sections/section_04'
require 'income_and_assets/pdf_fill/sections/section_05'
require 'income_and_assets/pdf_fill/sections/section_06'
require 'income_and_assets/pdf_fill/sections/section_07'
require 'income_and_assets/pdf_fill/sections/section_08'
require 'income_and_assets/pdf_fill/sections/section_09'
require 'income_and_assets/pdf_fill/sections/section_10'
require 'income_and_assets/pdf_fill/sections/section_11'
require 'income_and_assets/pdf_fill/sections/section_12'
require 'income_and_assets/pdf_fill/sections/section_13'

module IncomeAndAssets
  module PdfFill
    # The Va21p0969 Form
    class Va21p0969 < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper
      include IncomeAndAssets::Helpers

      # The Form ID
      FORM_ID = IncomeAndAssets::FORM_ID

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The path to the PDF template for the form
      TEMPLATE = "#{IncomeAndAssets::MODULE_PATH}/lib/income_and_assets/pdf_fill/pdfs/#{FORM_ID}.pdf".freeze

      # Form configuration hash (using "key" instead of "KEY" here as we will be modifying this later)
      key = {
        # 1a
        'veteranFullName' => {
          # form allows up to 39 characters but validation limits to 30,
          # so no overflow is needed
          'first' => {
            key: 'F[0].Page_4[0].VeteransName.First[0]'
          },
          'middle' => {
            key: 'F[0].Page_4[0].VeteransName.MI[0]'
          },
          # form allows up to 34 characters but validation limits to 30,
          # so no overflow is needed
          'last' => {
            key: 'F[0].Page_4[0].VeteransName.Last[0]'
          }
        },
        # 1b
        'veteranSocialSecurityNumber' => {
          key: 'F[0].Page_4[0].VeteransSSN[0]'
        },
        # 1c
        'vaFileNumber' => {
          key: 'F[0].Page_4[0].VeteransFileNumber[0]'
        },
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
      }

      # NOTE: Adding these over the span of multiple PRs too keep the LOC changed down.
      # Going to add them in reverse order so that the keys maintain the previous ordering
      SECTIONS = [Section3, Section4, Section5, Section6, Section7, Section8,
                  Section9, Section10, Section11,
                  Section12, Section13].freeze

      # Sections 5, 6, 7, 8, 9, 10, 11, 12, and 13
      SECTIONS.each { |section| key = key.merge(section::KEY) }

      # Form configuration hash
      KEY = key.freeze

      # Post-process form data to match the expected format.
      # Each section of the form is processed in its own expand function.
      #
      # @param _options [Hash] any options needed for post-processing
      #
      # @return [Hash] the processed form data
      #
      def merge_fields(_options = {})
        expand_veteran_info
        expand_claimant_info

        # Sections 5, 6, 7, 8, 9, 10, 11, 12, and 13
        SECTIONS.each { |section| section.new.expand(form_data) }

        form_data
      end

      private

      ##
      # Expands the veteran's information by extracting and capitalizing the first letter of the middle name.
      #
      # @note Modifies `form_data`
      #
      def expand_veteran_info
        veteran_middle_name = form_data['veteranFullName'].try(:[], 'middle')
        form_data['veteranFullName']['middle'] = veteran_middle_name.try(:[], 0)&.upcase
      end

      ##
      # Expands the claimants's information by extracting and capitalizing the first letter of the middle name.
      #
      # @note Modifies `form_data`
      #
      def expand_claimant_info
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
