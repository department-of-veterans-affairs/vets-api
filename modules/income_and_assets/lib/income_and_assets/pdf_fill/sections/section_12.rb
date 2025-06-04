# frozen_string_literal: true

require 'income_and_assets/pdf_fill/section'

module IncomeAndAssets
  module PdfFill
    # Section XII: Income Receipt Waivers
    class Section12 < Section
      # Section configuration hash
      KEY = {
        # 12a
        'incomeReceiptWaiver' => { key: 'F[0].#subform[9].DependentsWaiveReceiptsOfIncome12a[0]' },
        # 12b-12c (only space for 2 on form)
        'incomeReceiptWaivers' => {
          # Label for each waiver entry (e.g., 'Income Receipt Waiver 1')
          item_label: 'Income Receipt Waiver',
          limit: 2,
          first_key: 'otherRecipientRelationshipType',
          # Q1
          'recipientRelationship' => {
            key: "F[0].RelationshipToVeteran12[#{ITERATOR}]"
          },
          'recipientRelationshipOverflow' => {
            question_num: 12,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Relationship'
          },
          'otherRecipientRelationshipType' => {
            key: "F[0].OtherRelationship12[#{ITERATOR}]",
            question_num: 12,
            question_suffix: '(1)',
            question_text: "SPECIFY INCOME RECIPIENT'S RELATIONSHIP TO VETERAN",
            question_label: 'Other Relationship'
          },
          # Q2
          'recipientName' => {
            key: "F[0].IncomeRecipientName12[#{ITERATOR}]",
            question_num: 12,
            question_suffix: '(2)',
            question_text:
                'SPECIFY NAME OF INCOME RECIPIENT (Only needed if Custodian of child, child, parent, or other)',
            question_label: 'Recipient Name'
          },
          # Q3
          'payer' => {
            key: "F[0].IncomePayer12[#{ITERATOR}]",
            question_num: 12,
            question_suffix: '(3)',
            question_text: 'SPECIFY INCOME PAYER (Name of business, financial institution, etc.)',
            question_label: 'Income Payer'
          },
          # Q4
          'expectedIncome' => {
            'thousands' => {
              key: "F[0].AmountExpected1[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].AmountExpected2[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].AmountExpected3[#{ITERATOR}]"
            }
          },
          'expectedIncomeOverflow' => {
            dollar: true,
            question_num: 12,
            question_suffix: '(4)',
            question_text: 'IF THE INCOME RESUMES, WHAT AMOUNT DO YOU EXPECT TO RECEIVE?',
            question_label: 'Expected Income'
          },
          # Q5
          'paymentResumeDate' => {
            'month' => { key: "F[0].DatePaymentsResumeMonth[#{ITERATOR}]" },
            'day' => { key: "F[0].DatePaymentsResumeDay[#{ITERATOR}]" },
            'year' => { key: "F[0].DatePaymentsResumeYear[#{ITERATOR}]" }
          },
          'paymentResumeDateOverflow' => {
            question_num: 12,
            question_suffix: '(5)',
            question_text: 'DATE PAYMENTS WILL RESUME (MM/DD/YYYY)',
            question_label: 'Date Payments Will Resume'
          },
          'paymentWillNotResume' => {
            key: "F[0].IncomeWillNotResume12[#{ITERATOR}]"
          },
          'paymentWillNotResumeOverflow' => {
            question_num: 12,
            question_suffix: '(5)',
            question_text: 'This income will not resume',
            question_label: 'Payment Will Not Resume'
          },
          # Q6
          'waivedGrossMonthlyIncome' => {
            'thousands' => {
              key: "F[0].WaivedGrossMonthlyIncome1[#{ITERATOR}]"
            },
            'dollars' => {
              key: "F[0].WaivedGrossMonthlyIncome2[#{ITERATOR}]"
            },
            'cents' => {
              key: "F[0].WaivedGrossMonthlyIncome3[#{ITERATOR}]"
            }
          },
          'waivedGrossMonthlyIncomeOverflow' => {
            dollar: true,
            question_num: 12,
            question_suffix: '(6)',
            question_text: 'WAIVED GROSS MONTHLY INCOME',
            question_label: 'Waived Gross Monthly Income'
          }
        }
      }.freeze

      ##
      # Expands income receipt waivers by processing each income receipt waiver entry and setting an indicator
      # based on the presence of income receipt waivers.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        waivers = form_data['incomeReceiptWaivers']

        form_data['incomeReceiptWaiver'] = waivers&.length ? 0 : 1
        form_data['incomeReceiptWaivers'] = waivers&.map { |item| expand_item(item) }
      end

      ##
      # Expands an income receipt waivers's data by processing its attributes and transforming them into
      # structured output
      #
      # @param item [Hash]
      # @return [Hash]
      #
      def expand_item(item)
        recipient_relationship = item['recipientRelationship']
        payment_resume_date = item['paymentResumeDate']

        overflow_fields = %w[recipientRelationship expectedIncome waivedGrossMonthlyIncome]

        expanded = item.clone
        overflow_fields.each do |field|
          expanded["#{field}Overflow"] = item[field]
        end

        overrides = {
          'recipientRelationship' => IncomeAndAssets::Constants::RELATIONSHIPS[recipient_relationship],
          'expectedIncome' => split_currency_amount_sm(item['expectedIncome']),
          'paymentResumeDate' => split_date(payment_resume_date),
          'paymentResumeDateOverflow' => format_date_to_mm_dd_yyyy(payment_resume_date),
          'paymentWillNotResume' => payment_resume_date ? 0 : 1,
          'paymentWillNotResumeOverflow' => payment_resume_date ? 'NO' : 'YES',
          'waivedGrossMonthlyIncome' => split_currency_amount_sm(item['waivedGrossMonthlyIncome'])
        }

        expanded.merge(overrides)
      end
    end
  end
end
