# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va1010cg'
require_relative '../../../support/form1010cg_helpers/build_claim_data_for'

describe PdfFill::Forms::Va1010cg do
  include Form1010cgHelpers

  let(:form_subjects) { %w[veteran primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo] }

  describe '#merge_fields' do
    context 'certification' do
      let(:valid_certifications) do
        {
          veteran: %w[
            information-is-correct-and-true
            consent-to-caregivers-to-perform-care
          ],
          primaryCaregiver: {
            asFamilyMember: %w[
              information-is-correct-and-true
              at-least-18-years-of-age
              member-of-veterans-family
              agree-to-perform-services--as-primary
              understand-revocable-status--as-primary
              have-understanding-of-non-employment-relationship
            ],
            asNonFamilyMember: %w[
              information-is-correct-and-true
              at-least-18-years-of-age
              not-member-of-veterans-family
              currently-or-will-reside-with-veteran--as-primary
              agree-to-perform-services--as-primary
              understand-revocable-status--as-primary
              have-understanding-of-non-employment-relationship
            ]
          },
          secondaryCaregivers: {
            asFamilyMember: %w[
              information-is-correct-and-true
              at-least-18-years-of-age
              member-of-veterans-family
              agree-to-perform-services--as-secondary
              understand-revocable-status--as-secondary
              have-understanding-of-non-employment-relationship
            ],
            asNonFamilyMember: %w[
              information-is-correct-and-true
              at-least-18-years-of-age
              not-member-of-veterans-family
              currently-or-will-reside-with-veteran--as-secondary
              agree-to-perform-services--as-secondary
              understand-revocable-status--as-secondary
              have-understanding-of-non-employment-relationship
            ]
          }
        }
      end

      let(:valid_example_certs_for) do
        {
          veteran: valid_certifications[:veteran],
          primaryCaregiver: valid_certifications[:primaryCaregiver][:asFamilyMember],
          secondaryCaregiverOne: valid_certifications[:secondaryCaregivers][:asNonFamilyMember],
          secondaryCaregiverTwo: valid_certifications[:secondaryCaregivers][:asFamilyMember]
        }
      end

      let(:add_valid_certifications) do
        lambda do |data, form_subject|
          data['certifications'] = valid_example_certs_for[form_subject.to_sym]
        end
      end

      context 'if option :sign is false' do
        let(:fill_options) { { sign: false } }

        it 'does not add data to helpers' do
          form_data = {
            'veteran' => build_claim_data_for(:veteran, &add_valid_certifications),
            'primaryCaregiver' => build_claim_data_for(:primaryCaregiver, &add_valid_certifications),
            'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne, &add_valid_certifications),
            'secondaryCaregiverTwo' => build_claim_data_for(:secondaryCaregiverTwo, &add_valid_certifications)
          }

          filler_fields = described_class.new(form_data).merge_fields(fill_options)

          form_subjects.each do |form_subject|
            expect(filler_fields['helpers'][form_subject]['certify']).to eq(nil)
          end
        end
      end

      context 'if option :sign is true' do
        let(:fill_options) { { sign: true } }

        context 'and no certifications are present' do
          it 'does not add data to helpers' do
            form_data = {
              'veteran' => build_claim_data_for(:veteran),
              'primaryCaregiver' => build_claim_data_for(:primaryCaregiver),
              'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne),
              'secondaryCaregiverTwo' => build_claim_data_for(:secondaryCaregiverTwo)
            }

            filler_fields = described_class.new(form_data).merge_fields(fill_options)

            form_subjects.each do |form_subject|
              expect(filler_fields['helpers'][form_subject]['certify']).to eq(nil)
            end
          end
        end

        context 'and invalid certifications are present' do
          it 'does not add data to helpers' do
            form_data = {
              'veteran' => build_claim_data_for(:veteran) do |data|
                data['certifications'] = true
              end,
              'primaryCaregiver' => build_claim_data_for(:primaryCaregiver) do |data|
                data['certifications'] = []
              end,
              'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne) do |data|
                data['certifications'] = %w[some invalid data]
              end,
              'secondaryCaregiverTwo' => build_claim_data_for(:secondaryCaregiverTwo) do |data|
                data['certifications'] = [true, nil, '']
              end
            }

            filler_fields = described_class.new(form_data).merge_fields(fill_options)

            form_subjects.each do |form_subject|
              expect(filler_fields['helpers'][form_subject]['certify']).to eq(nil)
            end
          end
        end

        context 'and valid certifications are missing' do
          it 'does not add data to helpers' do
            form_data = {
              'veteran' => build_claim_data_for(:veteran) do |data|
                data['certifications'] = valid_certifications[:veteran].drop(1)
              end,
              'primaryCaregiver' => build_claim_data_for(:primaryCaregiver) do |data|
                data['certifications'] = valid_certifications[:primaryCaregiver][:asFamilyMember].drop(1)
              end,
              'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne) do |data|
                data['certifications'] = valid_certifications[:secondaryCaregivers][:asFamilyMember].drop(1)
              end,
              'secondaryCaregiverTwo' => build_claim_data_for(:secondaryCaregiverTwo) do |data|
                data['certifications'] = valid_certifications[:secondaryCaregivers][:asFamilyMember].drop(1)
              end
            }

            filler_fields = described_class.new(form_data).merge_fields(fill_options)

            form_subjects.each do |form_subject|
              expect(filler_fields['helpers'][form_subject]['certify']).to eq(nil)
            end
          end
        end

        context 'and valid certifications are provided' do
          context 'for veteran' do
            it "sets 'helpers'.'veteran'.'certify' to '1'" do
              form_data = { 'veteran' => build_claim_data_for(:veteran, &add_valid_certifications) }

              filler_fields = described_class.new(form_data).merge_fields(fill_options)

              expect(filler_fields['helpers']['veteran']['certify']).to eq('1')
            end
          end

          context 'for primaryCaregiver' do
            context 'when family member' do
              it "sets 'helpers'.'primaryCaregiver'.'certify' to '1'" do
                form_data = {
                  'primaryCaregiver' => build_claim_data_for(:primaryCaregiver) do |data|
                    data['certifications'] = valid_certifications[:primaryCaregiver][:asFamilyMember]
                  end
                }

                filler_fields = described_class.new(form_data).merge_fields(fill_options)

                expect(filler_fields['helpers']['primaryCaregiver']['certify']).to eq('1')
              end
            end

            context 'when non family member' do
              it "sets 'helpers'.'primaryCaregiver'.'certify' to '2'" do
                form_data = {
                  'primaryCaregiver' => build_claim_data_for(:primaryCaregiver) do |data|
                    data['certifications'] = valid_certifications[:primaryCaregiver][:asNonFamilyMember]
                  end
                }

                filler_fields = described_class.new(form_data).merge_fields(fill_options)

                expect(filler_fields['helpers']['primaryCaregiver']['certify']).to eq('2')
              end
            end
          end

          context 'for secondaryCaregiverOne' do
            context 'when family member' do
              it "sets 'helpers'.'secondaryCaregiverOne'.'certify' to '1'" do
                form_data = {
                  'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne) do |data|
                    data['certifications'] = valid_certifications[:secondaryCaregivers][:asFamilyMember]
                  end
                }

                filler_fields = described_class.new(form_data).merge_fields(fill_options)

                expect(filler_fields['helpers']['secondaryCaregiverOne']['certify']).to eq('1')
              end
            end

            context 'when non family member' do
              it "sets 'helpers'.'secondaryCaregiverOne'.'certify' to '2'" do
                form_data = {
                  'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne) do |data|
                    data['certifications'] = valid_certifications[:secondaryCaregivers][:asNonFamilyMember]
                  end
                }

                filler_fields = described_class.new(form_data).merge_fields(fill_options)

                expect(filler_fields['helpers']['secondaryCaregiverOne']['certify']).to eq('2')
              end
            end
          end

          context 'for secondaryCaregiverTwo' do
            context 'when family member' do
              it "sets 'helpers'.'secondaryCaregiverTwo'.'certify' to '1'" do
                form_data = {
                  'secondaryCaregiverTwo' => build_claim_data_for(:secondaryCaregiverTwo) do |data|
                    data['certifications'] = valid_certifications[:secondaryCaregivers][:asFamilyMember]
                  end
                }

                filler_fields = described_class.new(form_data).merge_fields(fill_options)

                expect(filler_fields['helpers']['secondaryCaregiverTwo']['certify']).to eq('1')
              end
            end

            context 'when non family member' do
              it "sets 'helpers'.'secondaryCaregiverTwo'.'certify' to '2'" do
                form_data = {
                  'secondaryCaregiverTwo' => build_claim_data_for(:secondaryCaregiverTwo) do |data|
                    data['certifications'] = valid_certifications[:secondaryCaregivers][:asNonFamilyMember]
                  end
                }

                filler_fields = described_class.new(form_data).merge_fields(fill_options)

                expect(filler_fields['helpers']['secondaryCaregiverTwo']['certify']).to eq('2')
              end
            end
          end

          context 'regardless the sort order' do
            it "sets 'helpers'.{subject}.'certify' " do
              form_data = {
                'veteran' => build_claim_data_for(:veteran, &add_valid_certifications),
                'primaryCaregiver' => build_claim_data_for(:primaryCaregiver, &add_valid_certifications),
                'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne, &add_valid_certifications),
                'secondaryCaregiverTwo' => build_claim_data_for(:secondaryCaregiverTwo, &add_valid_certifications)
              }

              form_subjects.each do |form_subject|
                form_data[form_subject]['certifications'].reverse!
              end

              filler_fields = described_class.new(form_data).merge_fields(fill_options)

              expect(filler_fields['helpers']['veteran']['certify']).to eq('1')
              expect(filler_fields['helpers']['primaryCaregiver']['certify']).to eq('1')
              expect(filler_fields['helpers']['secondaryCaregiverOne']['certify']).to eq('2')
              expect(filler_fields['helpers']['secondaryCaregiverTwo']['certify']).to eq('1')
            end
          end
        end
      end
    end
  end
end
