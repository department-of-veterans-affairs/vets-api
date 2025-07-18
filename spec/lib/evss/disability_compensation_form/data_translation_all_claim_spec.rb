# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/data_translation_all_claim'
require 'disability_compensation/factories/api_provider_factory'
require 'lighthouse/direct_deposit/response'

describe EVSS::DisabilityCompensationForm::DataTranslationAllClaim do
  subject { described_class.new(user, form_content, false) }

  let(:form_content) { { 'form526' => {} } }

  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
    frozen_time = Time.zone.parse '2020-11-05 13:19:50 -0500'
    Timecop.freeze(frozen_time)
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
  end

  after { Timecop.return }

  describe '#redacted' do
    context 'when the banking numbers include a *' do
      it 'returns true' do
        expect(subject.send('redacted', '**234', '1212')).to be(
          true
        )
      end
    end

    context 'when the banking numbers dont include a *' do
      it 'returns false' do
        expect(subject.send('redacted', '234', '1212')).to be(
          false
        )
      end
    end

    context 'when the banking numbers are nil' do
      it 'returns falsey' do
        expect(subject.send('redacted', nil, nil)).to be_falsey
      end
    end
  end

  describe '#overflow_text' do
    context 'when the form has a 4142 and the vet is terminally ill' do
      subject { described_class.new(user, form_content, true) }

      let(:form_content) do
        {
          'form526' => {
            'isTerminallyIll' => true
          }
        }
      end

      it 'adds the correct overflow text' do
        expect(subject.send(:overflow_text)).to eq "Corporate Flash Details\n" \
                                                   "This applicant has indicated that they're terminally ill.\n" \
                                                   'VA Form 21-4142/4142a has been completed by the applicant and ' \
                                                   'sent to the PMR contractor for processing in accordance with ' \
                                                   'M21-1 III.iii.1.D.2.'
      end
    end

    context 'when the form only has a 4142' do
      subject { described_class.new(user, form_content, true) }

      it 'adds the correct overflow text' do
        expect(subject.send(:overflow_text)).to eq 'VA Form 21-4142/4142a has been completed ' \
                                                   'by the applicant and sent to the PMR contractor ' \
                                                   'for processing in accordance with M21-1 III.iii.1.D.2.'
      end
    end

    context 'when the vet is terminally ill only' do
      let(:form_content) do
        {
          'form526' => {
            'isTerminallyIll' => true
          }
        }
      end

      it 'adds the correct overflow text' do
        expect(subject.send(:overflow_text)).to eq "Corporate Flash Details\n" \
                                                   "This applicant has indicated that they're terminally ill.\n"
      end
    end

    context 'when the vet has no overflow text' do
      let(:form_content) do
        {
          'form526' => {
            'isTerminallyIll' => false
          }
        }
      end

      it 'adds the correct overflow text' do
        expect(subject.send(:overflow_text)).to eq ''
      end
    end

    describe 'form 0781/a' do
      context 'when the form526_include_document_upload_list_in_overflow_text flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:form526_include_document_upload_list_in_overflow_text)
                                              .and_return(true)
        end

        let(:form_0781_note) do
          "VA Form 0781 has been completed by the applicant and sent to the VBMS eFolder.\n"
        end
        let(:form_0781a_note) do
          "VA Form 0781a has been completed by the applicant and sent to the VBMS eFolder.\n"
        end

        context 'when the form is submitted using the old v1 flow, producing two possible forms (0781 and 0781a)' do
          context 'when 0781 data is included without personal assault incidents' do
            let(:form_content) do
              {
                'form526' => {
                  'form0781' => {
                    'incidents' => [{ 'personalAssault' => false }]
                  }
                }
              }
            end

            it 'includes the 0781 note in the overflow text' do
              expect(described_class.new(user, form_content, false).send(:overflow_text)).to eq(form_0781_note)
            end
          end

          context 'when 0781 data is included with only personal assault incidents' do
            let(:form_content) do
              {
                'form526' => {
                  'form0781' => {
                    'incidents' => [{ 'personalAssault' => true },
                                    { 'personalAssault' => true }]
                  }
                }
              }
            end

            it 'includes the 0781a note in the overflow text' do
              expect(described_class.new(user, form_content, false).send(:overflow_text)).to eq(form_0781a_note)
            end
          end

          context 'when 0781 data is included with and without personalAssault incidents' do
            let(:form_content) do
              {
                'form526' => {
                  'form0781' => {
                    'incidents' => [{ 'personalAssault' => false },
                                    { 'personalAssault' => true },
                                    { 'personalAssault' => false }]
                  }
                }
              }
            end

            it 'includes both notes in the overflow text' do
              expected_note = "#{form_0781_note}#{form_0781a_note}"
              expect(described_class.new(user, form_content, false).send(:overflow_text)).to eq(expected_note)
            end
          end

          context 'when a form 0781/a is not included with Form 526' do
            before do
              allow(Flipper).to receive(:enabled?).with(:form526_include_document_upload_list_in_overflow_text)
                                                  .and_return(true)
            end

            let(:form_content) do
              {
                'form526' => {}
              }
            end

            it 'does not include a note in the overflow text' do
              expect(subject.send(:overflow_text)).to eq('')
            end
          end
        end

        context 'when the form is submitted using the new v2 flow, producing one form (form0781v2)' do
          context 'when 0781v2 data is included without personal assault incidents' do
            let(:form_content) do
              {
                'form526' => {
                  'form0781v2' => {
                    'incidents' => [
                      { 'personalAssault' => false },
                      { 'personalAssault' => false }
                    ]
                  }
                }
              }
            end

            it 'includes the 0781 note in the overflow text' do
              expect(described_class.new(user, form_content, false).send(:overflow_text)).to eq(form_0781_note)
            end
          end

          context 'when 0781v2 data is included with only assault incidents' do
            let(:form_content) do
              {
                'form526' => {
                  'form0781v2' => {
                    'incidents' => [
                      { 'personalAssault' => true }
                    ]
                  }
                }
              }
            end

            it 'includes the 0781 note in the overflow text' do
              expect(described_class.new(user, form_content, false).send(:overflow_text)).to eq(form_0781_note)
            end
          end

          context 'when 0781 data is included with and without personal assault incidents' do
            let(:form_content) do
              {
                'form526' => {
                  'form0781v2' => {
                    'incidents' => [
                      { 'personalAssault' => false },
                      { 'personalAssault' => true },
                      { 'personalAssault' => false }
                    ]
                  }
                }
              }
            end

            it 'includes the 0781 note in the overflow text' do
              expect(described_class.new(user, form_content, false).send(:overflow_text)).to eq(form_0781_note)
            end
          end

          context 'when a form 0781 is not included with Form 526' do
            before do
              allow(Flipper).to receive(:enabled?).with(:form526_include_document_upload_list_in_overflow_text)
                                                  .and_return(true)
            end

            let(:form_content) do
              {
                'form526' => {}
              }
            end

            it 'does not include a note in the overflow text' do
              expect(subject.send(:overflow_text)).to eq('')
            end
          end
        end
      end

      context 'when the form526_include_document_upload_list_in_overflow_text flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:form526_include_document_upload_list_in_overflow_text)
                                              .and_return(false)
        end

        it 'does not include a note in the overflow text' do
          expect(subject.send(:overflow_text)).to eq('')
        end
      end
    end

    describe 'veteran uploaded document list' do
      subject { described_class.new(user, form_content, false) }

      context 'when the veteran has uploaded documents to support the claim' do
        let(:file1_guid) { SecureRandom.uuid }
        let(:file2_guid) { SecureRandom.uuid }
        let(:form_content) do
          {
            'form526' => {
              'attachments' => [
                { 'confirmationCode' => file1_guid },
                { 'confirmationCode' => file2_guid }
              ]
            }
          }
        end

        let!(:file1) do
          create(
            :supporting_evidence_attachment,
            guid: file1_guid,
            file_data: { filename: 'my_file_1.pdf' }.to_json
          )
        end

        let!(:file2) do
          create(
            :supporting_evidence_attachment,
            guid: file2_guid,
            file_data: { filename: 'my_file_2.pdf' }.to_json
          )
        end

        let(:terminally_ill_note) do
          "Corporate Flash Details\n" \
            "This applicant has indicated that they're terminally ill.\n" \
        end

        let(:form_4142_note) do
          'VA Form 21-4142/4142a has been completed by the applicant and ' \
            'sent to the PMR contractor for processing in accordance with ' \
            'M21-1 III.iii.1.D.2.' \
        end

        let(:form_0781_note) do
          "VA Form 0781 has been completed by the applicant and sent to the VBMS eFolder.\n"
        end

        context 'when the form526_include_document_upload_list_in_overflow_text flipper is enabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:form526_include_document_upload_list_in_overflow_text)
                                                .and_return(true)
          end

          let(:file_list) do
            'The veteran uploaded 2 documents along with this claim. ' \
              "Please verify in VBMS eFolder.\n" \
              "my_file_1.pdf\n" \
              "my_file_2.pdf\n"
          end

          it 'includes a list of documents in the overflow text ordered alphabetically' do
            expect(subject.send(:overflow_text)).to eq(file_list)
          end

          context 'when the terminally ill, form 4142 and form 0781 notes are also present' do
            # Third argument, has_form4142, set to true so that note is present
            subject { described_class.new(user, form_content, true) }

            let(:form_content) do
              {
                'form526' => {
                  'isTerminallyIll' => true,
                  'attachments' => [
                    { 'confirmationCode' => file1_guid },
                    { 'confirmationCode' => file2_guid }
                  ],
                  'form0781' => {
                    'incidents' => [{ 'personalAssault' => false }]
                  }
                }
              }
            end

            it 'lists them in the order: 1. Terminally Ill, 2. Form 4142, 3. Form 0781, 4. Veteran file list' do
              expect(subject.send(:overflow_text)).to eq(
                terminally_ill_note +
                form_4142_note +
                form_0781_note +
                file_list
              )
            end
          end

          # EVSS restricts the maximum size included in the overflowText field
          describe 'overflowText character limits' do
            let(:attached_files_note) do
              # Actual document count would likely be larger in cases where we are worried about exceeding
              # size threshold, but we're only testing notes character length.
              # To avoid generating thousands of mock files/filenames, simply expect this text to match the number
              # of files we are actually mocking (2)
              'The veteran uploaded 2 documents along with this claim. ' \
                "Please verify in VBMS eFolder.\n"
            end

            context 'when no other notes are present' do
              # Third constructor argument, has_form4142, set to false so that note is not present
              subject { described_class.new(user, form_content, false) }

              let(:form_content) do
                {
                  'form526' => {
                    'isTerminallyIll' => false,
                    'attachments' => [
                      { 'confirmationCode' => file1_guid },
                      { 'confirmationCode' => file2_guid }
                    ]
                  }
                }
              end

              context 'when attached files note + file list alone would exceed the maximum allowed character length' do
                before do
                  over_the_limit_file_list_length = 4001 - attached_files_note.length

                  # Guarantee we exceed chracter length
                  allow(subject).to receive(:list_attachment_filenames).and_return(
                    Faker::Lorem.characters(number: over_the_limit_file_list_length)
                  )
                end

                it 'returns the attached files note only without listing the filenames' do
                  expect(subject.send(:overflow_text)).to eq(attached_files_note)
                end

                it 'increments a StatsD metric noting we truncated the file list' do
                  expect { subject.send(:overflow_text) }.to trigger_statsd_increment(
                    'api.form_526.overflow_text.veteran_file_list.excluded_from_overflow_text'
                  )
                end

                it 'logs the total file count' do
                  logging_time = Time.new(1985, 10, 26).utc

                  Timecop.freeze(logging_time) do
                    expect(Rails.logger).to receive(:info).with(
                      'Form526 Veteran-attached file names truncated from overflowText',
                      {
                        file_count: 2,

                        user_uuid: user.uuid,
                        timestamp: logging_time
                      }
                    )

                    subject.send(:overflow_text)
                  end
                end
              end
            end

            context 'when the sum total of all notes would exceed the maximum character length' do
              # Third argument, has_form4142, set to true so that note is present
              subject { described_class.new(user, form_content, true) }

              let(:form_content) do
                {
                  'form526' => {
                    'isTerminallyIll' => true,
                    'attachments' => [
                      { 'confirmationCode' => file1_guid },
                      { 'confirmationCode' => file2_guid }
                    ],
                    'form0781' => {
                      'incidents' => [{ 'personalAssault' => false }]
                    }
                  }
                }
              end

              before do
                notes_length = [terminally_ill_note, form_4142_note, form_0781_note, attached_files_note].join.length
                over_the_limit_file_list_length = 4001 - notes_length

                # Guarantee we exceed chracter length
                allow(subject).to receive(:list_attachment_filenames).and_return(
                  Faker::Lorem.characters(number: over_the_limit_file_list_length)
                )
              end

              it 'returns all notes but does not include the file list' do
                expect(subject.send(:overflow_text)).to eq(
                  terminally_ill_note +
                  form_4142_note +
                  form_0781_note +
                  attached_files_note
                )
              end

              it 'increments a StatsD metric noting we truncated the file list' do
                expect { subject.send(:overflow_text) }.to trigger_statsd_increment(
                  'api.form_526.overflow_text.veteran_file_list.excluded_from_overflow_text'
                )
              end

              it 'logs the total file count' do
                logging_time = Time.new(1985, 10, 26).utc

                Timecop.freeze(logging_time) do
                  expect(Rails.logger).to receive(:info).with(
                    'Form526 Veteran-attached file names truncated from overflowText',
                    {
                      file_count: 2,
                      user_uuid: user.uuid,
                      timestamp: logging_time
                    }
                  )

                  subject.send(:overflow_text)
                end
              end
            end

            context 'when the overflowText size allows for displaying the full file list' do
              # reset subject
              it 'increments a StatsD metric noting we included the full file list' do
                expect { subject.send(:overflow_text) }.to trigger_statsd_increment(
                  'api.form_526.overflow_text.veteran_file_list.included_in_overflow_text'
                )
              end

              it 'logs the total file count' do
                logging_time = Time.new(1985, 10, 26).utc

                Timecop.freeze(logging_time) do
                  expect(Rails.logger).to receive(:info).with(
                    'Form526 Veteran-attached file names included in overflowText',
                    {
                      file_count: 2,
                      user_uuid: user.uuid,
                      timestamp: logging_time
                    }
                  )

                  subject.send(:overflow_text)
                end
              end
            end
          end
        end

        context 'when the form526_include_document_upload_list_in_overflow_text flipper is disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:form526_include_document_upload_list_in_overflow_text)
                                                .and_return(false)
          end

          it 'does not include the list of documents in the overflow text' do
            expect(subject.send(:overflow_text)).to eq('')
          end
        end
      end

      context 'when the veteran has not uploaded documents to support the claim' do
        it 'does not include the list of documents in the overflow text' do
          expect(subject.send(:overflow_text)).to eq('')
        end

        it 'does not increment a StatsD metric noting we excluded the file list' do
          expect { subject.send(:overflow_text) }.not_to trigger_statsd_increment(
            'api.form_526.overflow_text.veteran_file_list.excluded_from_overflow_text'
          )
        end

        it 'does not StatsD metric noting we included the file list' do
          expect { subject.send(:overflow_text) }.not_to trigger_statsd_increment(
            'api.form_526.overflow_text.veteran_file_list.included_in_overflow_text'
          )
        end
      end
    end
  end

  describe '#translate_banking_info' do
    context 'when provided banking info' do
      let(:form_content) do
        {
          'form526' => {
            'bankName' => 'test',
            'bankAccountType' => 'checking',
            'bankAccountNumber' => '1234567890',
            'bankRoutingNumber' => '0987654321'
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_banking_info)).to eq 'directDeposit' => {
          'accountType' => 'CHECKING',
          'accountNumber' => '1234567890',
          'routingNumber' => '0987654321',
          'bankName' => 'test'
        }
      end
    end

    context 'when the banking info is redacted' do
      let(:user) { create(:user, :loa3, :accountable, icn: '1012666073V986297') }

      it 'gathers the banking info from Lighthouse DirectDeposit' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          expect(subject.send(:translate_banking_info)).to eq 'directDeposit' => {
            'accountType' => 'CHECKING',
            'accountNumber' => '1234567890',
            'routingNumber' => '031000503',
            'bankName' => 'WELLS FARGO BANK'
          }
        end
      end
    end

    context 'when not provided banking info' do
      let(:user) { create(:user, :loa3, :accountable, icn: '1012666073V986297') }

      context 'and the Lighthouse DirectDeposit service has the account info' do
        it 'gathers the banking info from the LH DirectDeposit' do
          VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
            expect(subject.send(:translate_banking_info)).to eq 'directDeposit' => {
              'accountType' => 'CHECKING',
              'accountNumber' => '1234567890',
              'routingNumber' => '031000503',
              'bankName' => 'WELLS FARGO BANK'
            }
          end
        end
      end

      context 'and the Lighthouse DirectDeposit service does not have the account info' do
        let(:response) { Lighthouse::DirectDeposit::Response.new(200, nil, nil, nil) }

        it 'does not set payment information' do
          expect_any_instance_of(DirectDeposit::Client).to receive(:get_payment_info).and_return(response)
          expect(subject.send(:translate_banking_info)).to eq({})
        end
      end
    end
  end

  describe '#translate_service_pay' do
    context 'when no relevant data is provided' do
      it 'returns an empty hash' do
        expect(subject.send(:translate_service_pay)).to eq({})
      end
    end

    context 'when provided benefit waving data' do
      let(:form_content) do
        {
          'form526' => {
            'waiveTrainingPay' => true,
            'waiveRetirementPay' => true
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_pay)).to eq 'servicePay' => {
          'waiveVABenefitsToRetainTrainingPay' => true,
          'waiveVABenefitsToRetainRetiredPay' => true
        }
      end
    end

    context 'when provided military retired data' do
      let(:form_content) { { 'form526' => { 'militaryRetiredPayBranch' => 'Air Force' } } }

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_pay)).to eq 'servicePay' => {
          'militaryRetiredPay' => {
            'receiving' => true,
            'payment' => {
              'serviceBranch' => 'Air Force'
            }
          }
        }
      end
    end

    context 'when provided separation pay data' do
      let(:form_content) do
        {
          'form526' => {
            'hasSeparationPay' => true,
            'separationPayBranch' => 'Air Force',
            'separationPayDate' => '2018-XX-XX'
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_pay)).to eq 'servicePay' => {
          'separationPay' => {
            'received' => true,
            'payment' => {
              'serviceBranch' => 'Air Force'
            },
            'receivedDate' => {
              'year' => '2018'
            }
          }
        }
      end
    end
  end

  describe '#separation_pay' do
    context 'when given all separation pay data' do
      let(:form_content) do
        {
          'form526' => {
            'hasSeparationPay' => true,
            'separationPayBranch' => 'Air Force',
            'separationPayDate' => '2018-XX-XX'
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:separation_pay)).to eq(
          'received' => true,
          'payment' => {
            'serviceBranch' => 'Air Force'
          },
          'receivedDate' => {
            'year' => '2018'
          }
        )
      end
    end

    context 'when `hasSeparationPay` is false' do
      let(:form_content) do
        {
          'form526' => {
            'hasSeparationPay' => false,
            'separationPayBranch' => 'Air Force',
            'separationPayDate' => '2018-XX-XX'
          }
        }
      end

      it 'does not translate separation pay' do
        expect(subject.send(:separation_pay)).to be_nil
      end
    end

    context 'when `hasSeparationPay` does not exist' do
      let(:form_content) do
        {
          'form526' => {
            'separationPayBranch' => 'Air Force',
            'separationPayDate' => '2018-XX-XX'
          }
        }
      end

      it 'does not translate separation pay' do
        expect(subject.send(:separation_pay)).to be_nil
      end
    end

    context 'when given no optional separation pay data' do
      let(:form_content) do
        {
          'form526' => {
            'hasSeparationPay' => true
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:separation_pay)).to eq('received' => true)
      end
    end
  end

  describe '#translate_service_info' do
    context 'when provided service period data' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => '1990-01-02'
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            }
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '1990-01-02'
            }
          ]
        }
      end
    end

    context 'when provided service separation location' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => '2021-04-02'
                  },
                  'serviceBranch' => 'Air Force'
                }
              ],
              'separationLocation' => {
                'separationLocationCode' => '98283',
                'separationLocationName' => 'AF Academy'
              }
            }
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '2021-04-02'
            }
          ],
          'separationLocationCode' => '98283',
          'separationLocationName' => 'AF Academy'
        }
      end
    end

    context 'when provided confinements data' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => '1990-01-02'
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            },
            'confinements' => [
              {
                'from' => '1984-01-31',
                'to' => '1985-02-01'
              }
            ]
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '1990-01-02'
            }
          ],
          'confinements' => [
            {
              'confinementBeginDate' => '1984-01-31',
              'confinementEndDate' => '1985-02-01'
            }
          ]
        }
      end
    end

    context 'when provided national guard service data' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => '1990-01-02'
                  },
                  'serviceBranch' => 'Air Force'
                }
              ],
              'reservesNationalGuardService' => {
                'obligationTermOfServiceDateRange' => {
                  'from' => '2000-01-04',
                  'to' => '2004-01-04'
                },
                'title10Activation' => {
                  'anticipatedSeparationDate' => '2020-01-01',
                  'title10ActivationDate' => '1999-03-04'
                },
                'unitName' => 'Seal Team Six',
                'unitPhone' => '1231231231'
              }
            },
            'waiveTrainingPay' => true,
            'hasTrainingPay' => true
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '1990-01-02'
            }
          ],
          'reservesNationalGuardService' => {
            'obligationTermOfServiceFromDate' => '2000-01-04',
            'obligationTermOfServiceToDate' => '2004-01-04',
            'receivingInactiveDutyTrainingPay' => true,
            'title10Activation' => {
              'anticipatedSeparationDate' => '2020-01-01',
              'title10ActivationDate' => '1999-03-04'
            },
            'unitName' => 'Seal Team Six',
            'unitPhone' => {
              'areaCode' => '123',
              'phoneNumber' => '1231231'
            }
          }
        }
      end
    end

    context 'when provided alternate names data' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => '1990-01-02'
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            },
            'alternateNames' => [
              {
                'first' => 'Steve',
                'middle' => 'Steverson',
                'last' => 'Stevington'
              },
              {
                'first' => 'Steve',
                'middle' => 'Steverson',
                'last' => 'Stevington'
              }
            ]
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_service_info)).to eq 'serviceInformation' => {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1980-02-05',
              'activeDutyEndDate' => '1990-01-02'
            }
          ],
          'alternateNames' => [
            {
              'firstName' => 'Steve',
              'middleName' => 'Steverson',
              'lastName' => 'Stevington'
            }
          ]
        }
      end
    end
  end

  describe '#service_branch' do
    context 'when the service branch is on the branch map list' do
      it 'transforms it to the correct string' do
        expect(subject.send(:service_branch, 'Air Force Reserve')).to eq 'Air Force Reserves'
        expect(subject.send(:service_branch, 'Army Reserve')).to eq 'Army Reserves'
        expect(subject.send(:service_branch, 'Coast Guard Reserve')).to eq 'Coast Guard Reserves'
        expect(subject.send(:service_branch, 'Marine Corps Reserve')).to eq 'Marine Corps Reserves'
        expect(subject.send(:service_branch, 'Navy Reserve')).to eq 'Navy Reserves'
        expect(subject.send(:service_branch, 'NOAA')).to eq 'National Oceanic & Atmospheric Administration'
      end
    end

    context 'when the service branch is not on the branch map' do
      it 'keeps the service branch as is' do
        expect(subject.send(:service_branch, 'Navy')).to eq 'Navy'
      end
    end
  end

  describe '#translate_veteran' do
    context 'when provided email, phone, and va employee' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {},
            'phoneAndEmail' => {
              'emailAddress' => 'tester@adhocteam.us',
              'primaryPhone' => '5551231234'
            },
            'isVaEmployee' => true
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'type' => 'INTERNATIONAL'
          },
          'emailAddress' => 'tester@adhocteam.us',
          'daytimePhone' => {
            'areaCode' => '555',
            'phoneNumber' => '1231234'
          },
          'currentlyVAEmployee' => true
        }
      end
    end

    context 'when given a Domestic address' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR',
              'addressLine1' => '1234 Couch Street',
              'zipCode' => '12345-6789'
            }
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'addressLine1' => '1234 Couch Street',
            'city' => 'Portland',
            'country' => 'USA',
            'state' => 'OR',
            'type' => 'DOMESTIC',
            'zipFirstFive' => '12345',
            'zipLastFour' => '6789'
          }
        }
      end
    end

    context 'when given a Military address' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {
              'country' => 'Germany',
              'city' => ' apo ',
              'state' => 'AA',
              'addressLine1' => '1234 Couch Strasse',
              'zipCode' => '12345-6789'
            }
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'addressLine1' => '1234 Couch Strasse',
            'militaryPostOfficeTypeCode' => 'APO',
            'country' => 'Germany',
            'militaryStateCode' => 'AA',
            'type' => 'MILITARY',
            'zipFirstFive' => '12345',
            'zipLastFour' => '6789'
          }
        }
      end
    end

    context 'when given an International address' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {
              'country' => 'Germany',
              'city' => 'Hamburg',
              'addressLine1' => '1234 Couch Strasse'
            }
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'addressLine1' => '1234 Couch Strasse',
            'city' => 'Hamburg',
            'country' => 'Germany',
            'type' => 'INTERNATIONAL',
            'internationalPostalCode' => '732'
          }
        }
      end
    end

    context 'when given a change of address' do
      let(:form_content) do
        {
          'form526' => {
            'mailingAddress' => {},
            'forwardingAddress' => {
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR',
              'addressLine1' => '1234 Couch Street',
              'zipCode' => '12345-6789',
              'effectiveDate' => {
                'from' => '2018-02-01',
                'to' => '2018-02-30'
              }
            }
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_veteran)).to eq 'veteran' => {
          'currentMailingAddress' => {
            'type' => 'INTERNATIONAL'
          },
          'changeOfAddress' => {
            'addressLine1' => '1234 Couch Street',
            'city' => 'Portland',
            'country' => 'USA',
            'state' => 'OR',
            'type' => 'DOMESTIC',
            'zipFirstFive' => '12345',
            'zipLastFour' => '6789',
            'beginningDate' => '2018-02-01',
            'endingDate' => '2018-02-30',
            'addressChangeType' => 'TEMPORARY'
          }
        }
      end
    end
  end

  describe '#translate_change_of_address' do
    context 'when given an effectiveDate `to` key' do
      let(:address) do
        {
          'effectiveDate' => {
            'from' => '2018-02-01',
            'to' => '2018-02-30'
          }
        }
      end

      it 'sets the address as TEMPORARY' do
        expect(subject.send(:translate_change_of_address, address)).to eq(
          'addressChangeType' => 'TEMPORARY',
          'beginningDate' => '2018-02-01',
          'endingDate' => '2018-02-30',
          'type' => 'INTERNATIONAL'
        )
      end
    end

    context 'when not given an effectiveDate `to` key' do
      let(:address) do
        {
          'effectiveDate' => {
            'from' => '2018-02-01'
          }
        }
      end

      it 'sets the address as PERMANENT' do
        expect(subject.send(:translate_change_of_address, address)).to eq(
          'addressChangeType' => 'PERMANENT',
          'beginningDate' => '2018-02-01',
          'type' => 'INTERNATIONAL'
        )
      end
    end
  end

  describe '#split_zip_code' do
    context 'when given a 5 number zip code' do
      it 'returns the correct split' do
        expect(subject.send(:split_zip_code, '12345')).to eq ['12345', '', nil]
      end
    end

    context 'when given a 9 number zip code' do
      it 'returns the correct split' do
        expect(subject.send(:split_zip_code, '123456789')).to eq ['12345', '', '6789']
      end
    end

    context 'when given a 9 number zip code with a hyphen' do
      it 'returns the correct split' do
        expect(subject.send(:split_zip_code, '12345-6789')).to eq ['12345', '-', '6789']
      end
    end
  end

  describe '#translate_homelessness' do
    context 'when `homelessOrAtRisk` is set to `no`' do
      let(:form_content) do
        {
          'form526' => {
            'homelessOrAtRisk' => 'no'
          }
        }
      end

      it 'returns nil' do
        expect(subject.send(:translate_homelessness)).to be_nil
      end
    end

    context 'when `homelessOrAtRisk` is set to `homeless`' do
      context 'and the user is fleeing their housing' do
        let(:form_content) do
          {
            'form526' => {
              'homelessOrAtRisk' => 'homeless',
              'needToLeaveHousing' => true,
              'otherHomelessHousing' => 'other living situation',
              'homelessnessContact' => {
                'name' => 'Steve Stevington',
                'phoneNumber' => '5551231234'
              }
            }
          }
        end

        it 'translates the data correctly' do
          expect(subject.send(:translate_homelessness)).to eq(
            'pointOfContact' => {
              'pointOfContactName' => 'Steve Stevington',
              'primaryPhone' => {
                'areaCode' => '555',
                'phoneNumber' => '1231234'
              }
            },
            'currentlyHomeless' => {
              'homelessSituationType' => 'FLEEING_CURRENT_RESIDENCE',
              'otherLivingSituation' => 'other living situation'
            }
          )
        end
      end

      context 'and the user is not fleeing their housing' do
        let(:form_content) do
          {
            'form526' => {
              'homelessOrAtRisk' => 'homeless',
              'homelessHousingSituation' => 'shelter',
              'otherHomelessHousing' => 'other living situation',
              'homelessnessContact' => {
                'name' => 'Steve Stevington',
                'phoneNumber' => '5551231234'
              }
            }
          }
        end

        it 'translates the data correctly' do
          expect(subject.send(:translate_homelessness)).to eq(
            'pointOfContact' => {
              'pointOfContactName' => 'Steve Stevington',
              'primaryPhone' => {
                'areaCode' => '555',
                'phoneNumber' => '1231234'
              }
            },
            'currentlyHomeless' => {
              'homelessSituationType' => 'LIVING_IN_A_HOMELESS_SHELTER',
              'otherLivingSituation' => 'other living situation'
            }
          )
        end
      end
    end

    context 'when `homelessOrAtRisk` is set to `atRisk`' do
      let(:form_content) do
        {
          'form526' => {
            'homelessOrAtRisk' => 'atRisk',
            'atRiskHousingSituation' => 'losingHousing',
            'otherAtRiskHousing' => 'other living situation',
            'homelessnessContact' => {
              'name' => 'Steve Stevington',
              'phoneNumber' => '5551231234'
            }
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_homelessness)).to eq(
          'pointOfContact' => {
            'pointOfContactName' => 'Steve Stevington',
            'primaryPhone' => {
              'areaCode' => '555',
              'phoneNumber' => '1231234'
            }
          },
          'homelessnessRisk' => {
            'homelessnessRiskSituationType' => 'HOUSING_WILL_BE_LOST_IN_30_DAYS',
            'otherLivingSituation' => 'other living situation'
          }
        )
      end
    end
  end

  describe '#translate_treatments' do
    context 'when no treatment centers are provided' do
      it 'returns an empty hash' do
        expect(subject.send(:translate_treatments)).to eq({})
      end
    end

    context 'when given a treatment center' do
      let(:form_content) do
        {
          'form526' => {
            'vaTreatmentFacilities' => [
              {
                'treatmentDateRange' => {
                  'from' => '2018-01-01',
                  'to' => '2018-02-XX'
                },
                'treatmentCenterName' => 'Super  _,!?Hospital    \'&\' "More" (#2.0)',
                'treatmentCenterAddress' => {
                  'country' => 'USA',
                  'city' => 'Portland',
                  'state' => 'OR'
                },
                'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3]
              }
            ]
          }
        }
      end

      it 'translates the data correctly, including regex evaluation of center name' do
        expect(subject.send(:translate_treatments)).to eq 'treatments' => [
          {
            'startDate' => {
              'year' => '2018',
              'month' => '01',
              'day' => '01'
            },
            'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3],
            'center' => {
              'name' => 'Super Hospital \'&\' "More" (#2.0)',
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR'
            }
          }
        ]
      end
    end

    context 'when given a treatment center with no `to` date' do
      let(:form_content) do
        {
          'form526' => {
            'vaTreatmentFacilities' => [
              {
                'treatmentDateRange' => {
                  'from' => '2018-01-01',
                  'to' => ''
                },
                'treatmentCenterName' => 'Super Hospital',
                'treatmentCenterAddress' => {
                  'country' => 'USA',
                  'city' => 'Portland',
                  'state' => 'OR'
                },
                'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3]
              }
            ]
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_treatments)).to eq 'treatments' => [
          {
            'startDate' => {
              'year' => '2018',
              'month' => '01',
              'day' => '01'
            },
            'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3],
            'center' => {
              'name' => 'Super Hospital',
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR'
            }
          }
        ]
      end
    end

    context 'when given a treatment center an incomplete "from" date' do
      let(:form_content) do
        {
          'form526' => {
            'vaTreatmentFacilities' => [
              {
                'treatmentDateRange' => {
                  'from' => 'XXXX-07-XX',
                  'to' => ''
                },
                'treatmentCenterName' => 'Super Hospital',
                'treatmentCenterAddress' => {
                  'country' => 'USA',
                  'city' => 'Portland',
                  'state' => 'OR'
                },
                'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3]
              }
            ]
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_treatments)).to eq 'treatments' => [
          {
            'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3],
            'center' => {
              'name' => 'Super Hospital',
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR'
            }
          }
        ]
      end
    end

    context 'when given a treatment center with no date' do
      let(:form_content) do
        {
          'form526' => {
            'vaTreatmentFacilities' => [
              {
                'treatmentCenterName' => 'Super Hospital',
                'treatmentCenterAddress' => {
                  'country' => 'USA',
                  'city' => 'Portland',
                  'state' => 'OR'
                },
                'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3]
              }
            ]
          }
        }
      end

      it 'translates the data correctly' do
        expect(subject.send(:translate_treatments)).to eq 'treatments' => [
          {
            'treatedDisabilityNames' => %w[PTSD PTSD2 PTSD3],
            'center' => {
              'name' => 'Super Hospital',
              'country' => 'USA',
              'city' => 'Portland',
              'state' => 'OR'
            }
          }
        ]
      end
    end
  end

  describe '#translate_disabilities' do
    context 'when there are no new disabilities' do
      let(:form_content) do
        {
          'form526' => {
            'ratedDisabilities' => [
              {
                'diagnosticCode' => 9999,
                'disabilityActionType' => 'INCREASE',
                'name' => 'PTSD (post traumatic stress disorder)',
                'ratedDisabilityId' => '1100583'
              }
            ]
          }
        }
      end

      it 'translates only the preexisting disabilities' do
        expect(subject.send(:translate_disabilities)).to eq 'disabilities' => [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'INCREASE',
            'name' => 'PTSD (post traumatic stress disorder)',
            'ratedDisabilityId' => '1100583'
          }
        ]
      end
    end

    context 'when there is an extraneous `NONE` action type disability' do
      let(:form_content) do
        {
          'form526' => {
            'ratedDisabilities' => [
              {
                'diagnosticCode' => 9999,
                'disabilityActionType' => 'INCREASE',
                'name' => 'PTSD (post traumatic stress disorder)',
                'ratedDisabilityId' => '1100583'
              },
              {
                'diagnosticCode' => 9998,
                'disabilityActionType' => 'NONE',
                'name' => 'Arthritis',
                'ratedDisabilityId' => '1100582'
              }
            ]
          }
        }
      end

      it 'does not translate the disability with NONE action type' do
        expect(subject.send(:translate_disabilities)).to eq 'disabilities' => [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'INCREASE',
            'name' => 'PTSD (post traumatic stress disorder)',
            'ratedDisabilityId' => '1100583'
          }
        ]
      end
    end

    context 'when there is an `NONE` action type disability but it has a new secondary disability' do
      let(:form_content) do
        {
          'form526' => {
            'ratedDisabilities' => [
              {
                'diagnosticCode' => 9999,
                'disabilityActionType' => 'NONE',
                'name' => 'PTSD (post traumatic stress disorder)',
                'ratedDisabilityId' => '1100583'
              }
            ],
            'newSecondaryDisabilities' => [
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition',
                'specialIssues' => ['POW'],
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'PTSD (post traumatic stress disorder)'
              }
            ]
          }
        }
      end

      it 'translates the NONE action type disability and its secondary disability' do
        expect(subject.send(:translate_disabilities)).to eq 'disabilities' => [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NONE',
            'name' => 'PTSD (post traumatic stress disorder)',
            'ratedDisabilityId' => '1100583',
            'secondaryDisabilities' => [
              {
                'name' => 'secondary condition',
                'disabilityActionType' => 'SECONDARY',
                'specialIssues' => ['POW'],
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              }
            ]
          }
        ]
      end
    end
  end

  describe '#translate_new_disabilities' do
    context 'when there is a NEW disability' do
      let(:form_content) do
        {
          'form526' => {
            'newPrimaryDisabilities' => [
              {
                'cause' => 'NEW',
                'condition' => 'new condition',
                'classificationCode' => 'Test Code',
                'specialIssues' => ['POW'],
                'primaryDescription' => 'new condition description'
              }
            ]
          }
        }
      end

      it 'translates only the NEW disabilities' do
        expect(subject.send(:translate_new_primary_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'new condition',
            'classificationCode' => 'Test Code',
            'specialIssues' => ['POW'],
            'serviceRelevance' => "Caused by an in-service event, injury, or exposure\nnew condition description",
            'cause' => 'NEW'
          }
        ]
      end
    end

    context 'when there is a WORSENED disability' do
      let(:form_content) do
        {
          'form526' => {
            'newPrimaryDisabilities' => [
              {
                'cause' => 'WORSENED',
                'condition' => 'worsened condition',
                'classificationCode' => 'Test Code',
                'specialIssues' => ['POW'],
                'worsenedDescription' => 'worsened condition description',
                'worsenedEffects' => 'worsened effects'
              }
            ]
          }
        }
      end

      it 'translates only the WORSENED disabilities' do
        expect(subject.send(:translate_new_primary_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'worsened condition',
            'classificationCode' => 'Test Code',
            'specialIssues' => ['POW'],
            'serviceRelevance' =>
              "Worsened because of military service\nworsened condition description: worsened effects",
            'cause' => 'WORSENED'
          }
        ]
      end
    end

    context 'when there is a VA disability' do
      let(:form_content) do
        {
          'form526' => {
            'newPrimaryDisabilities' => [
              {
                'cause' => 'VA',
                'condition' => 'va condition',
                'classificationCode' => 'Test Code',
                'specialIssues' => ['POW'],
                'vaMistreatmentDescription' => 'va condition description',
                'vaMistreatmentLocation' => 'va location',
                'vaMistreatmentDate' => 'the third of october'
              }
            ]
          }
        }
      end

      it 'translates only the VA disabilities' do
        expect(subject.send(:translate_new_primary_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'va condition',
            'classificationCode' => 'Test Code',
            'specialIssues' => ['POW'],
            'serviceRelevance' =>
              "Caused by VA care\nEvent: va condition description\n" \
              "Location: va location\nTimeFrame: the third of october",
            'cause' => 'VA'
          }
        ]
      end
    end

    context 'when there are SECONDARY disabilities' do
      let(:form_content) do
        {
          'form526' => {
            'newSecondaryDisabilities' => [
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition',
                'classificationCode' => 'Test Code',
                'specialIssues' => ['POW'],
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'PTSD disability'
              },
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition2',
                'specialIssues' => ['POW'],
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'PTSD disability2'
              },
              {
                'cause' => 'SECONDARY',
                'condition' => 'secondary condition3',
                'specialIssues' => ['POW'],
                'causedByDisabilityDescription' => 'secondary description',
                'causedByDisability' => 'ptsd disability2' # check that the match is case insensitive
              }
            ]
          }
        }
      end

      let(:disability) do
        [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD disability',
            'classificationCode' => 'Test Code',
            'ratedDisabilityId' => '1100583'
          },
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD disability2',
            'ratedDisabilityId' => '1100583'
          }
        ]
      end

      it 'translates SECONDARY disability to a current disability' do
        expect(subject.send(:translate_new_secondary_disabilities, disability)).to eq [
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD disability',
            'classificationCode' => 'Test Code',
            'ratedDisabilityId' => '1100583',
            'secondaryDisabilities' => [
              {
                'name' => 'secondary condition',
                'classificationCode' => 'Test Code',
                'disabilityActionType' => 'SECONDARY',
                'specialIssues' => ['POW'],
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              }
            ]
          },
          {
            'diagnosticCode' => 9999,
            'disabilityActionType' => 'NEW',
            'name' => 'PTSD disability2',
            'ratedDisabilityId' => '1100583',
            'secondaryDisabilities' => [
              {
                'name' => 'secondary condition2',
                'disabilityActionType' => 'SECONDARY',
                'specialIssues' => ['POW'],
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              },
              {
                'name' => 'secondary condition3',
                'disabilityActionType' => 'SECONDARY',
                'specialIssues' => ['POW'],
                'serviceRelevance' => "Caused by a service-connected disability\nsecondary description"
              }
            ]
          }
        ]
      end
    end

    context 'when there is a new disability without a classificationCode' do
      let(:form_content) do
        {
          'form526' => {
            'newPrimaryDisabilities' => [
              {
                'cause' => 'NEW',
                'condition' => '  brand [new] disability { to  be } rated',
                'primaryDescription' => 'new condition description'
              }
            ]
          }
        }
      end

      it 'translates only the NEW disabilities' do
        expect(subject.send(:translate_new_primary_disabilities, [])).to eq [
          {
            'disabilityActionType' => 'NEW',
            'name' => 'brand new disability to be rated',
            'serviceRelevance' => "Caused by an in-service event, injury, or exposure\nnew condition description",
            'cause' => 'NEW'
          }
        ]
      end
    end

    describe '#scrub_disability_condition' do
      context 'when given a condition name' do
        let(:condition1) { 'this is only a test' }
        let(:condition2) { '  this    is only     a      test ' }
        let(:condition3) { '[ \'this\'  is ] (only) a ’test’' }
        let(:condition4) { 'this-is,only.a-test' }
        let(:condition5) { 'this ¢is onÈly a töest' }

        it 'scrubs out any illegal characters' do
          expect(subject.send(:scrub_disability_condition, condition1)).to eq 'this is only a test'
          expect(subject.send(:scrub_disability_condition, condition2)).to eq 'this is only a test'
          expect(subject.send(:scrub_disability_condition, condition3)).to eq '\'this\' is (only) a test'
          expect(subject.send(:scrub_disability_condition, condition4)).to eq 'this-is,only.a-test'
          expect(subject.send(:scrub_disability_condition, condition5)).to eq 'this is only a test'
        end
      end
    end

    describe '#approximate_date' do
      context 'when there is a full date' do
        let(:date) { '2099-12-01' }

        it 'returns the year, month, and day' do
          expect(subject.send(:approximate_date, date)).to include(
            'year' => '2099',
            'month' => '12',
            'day' => '01'
          )
        end
      end

      context 'when there is a partial date (year and month)' do
        let(:date) { '2099-12-XX' }

        it 'returns the year and month' do
          expect(subject.send(:approximate_date, date)).to include(
            'year' => '2099',
            'month' => '12'
          )
        end
      end

      context 'when there is a partial date (year only)' do
        let(:date) { '2099-XX-XX' }

        it 'returns the year' do
          expect(subject.send(:approximate_date, date)).to include(
            'year' => '2099'
          )
        end
      end

      context 'when there is no date' do
        let(:date) { '' }

        it 'returns the year' do
          expect(subject.send(:approximate_date, date)).to be_nil
        end
      end
    end
  end

  describe '#translateStartedFormVersion' do
    context 'no startedFormVersion on input form' do
      let(:form_content) do
        {
          'form526' => {}
        }
      end

      it 'adds in startedFormVersion when it was missing' do
        expect(subject.send(:translate_started_form_version)).to eq({
                                                                      'startedFormVersion' => '2019'
                                                                    })
      end
    end

    context 'startedFormVersion is 2022' do
      let(:form_content) do
        {
          'form526' => {
            'startedFormVersion' => '2022'
          }
        }
      end

      it 'adds in startedFormVersion when it was missing' do
        expect(subject.send(:translate_started_form_version)).to eq({
                                                                      'startedFormVersion' => '2022'
                                                                    })
      end
    end

    context 'startedFormVersion is 2019' do
      let(:form_content) do
        {
          'form526' => {
            'startedFormVersion' => '2019'
          }
        }
      end

      it 'fills in 2019 startedFormVersion' do
        expect(subject.send(:translate_started_form_version)).to eq({
                                                                      'startedFormVersion' => '2019'
                                                                    })
      end
    end
  end

  describe '#add_toxic_exposure' do
    let(:form_content) do
      {
        'form526' => {
          'toxicExposure' => {
            'gulfWar1990' => {
              'iraq' => true,
              'kuwait' => true,
              'qatar' => true
            }
          }
        }
      }
    end

    it 'returns toxic exposure' do
      expect(subject.send(:add_toxic_exposure)).to eq(
        {
          'toxicExposure' => {
            'gulfWar1990' => {
              'iraq' => true,
              'kuwait' => true,
              'qatar' => true
            }
          }
        }
      )
    end
  end

  describe '#application_expiration_date' do
    it 'returns the application creation date + 365 days' do
      expect(subject.send(:application_expiration_date)).to eq '2021-11-05T18:19:50Z'
    end
  end

  describe '#translate_bdd' do
    let(:today) { Time.now.in_time_zone('Central Time (US & Canada)').to_date }

    context 'when rad date is > 180 away' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => (today + 181).to_s
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            }
          }
        }
      end

      it 'throws 422 error' do
        expect { subject.send(:bdd_qualified?) }.to raise_error(
          Common::Exceptions::UnprocessableEntity
        ) { |e|
          expect(e.errors[0].detail).to match(/more than 180 days/)
        }
      end
    end

    context 'when rad date is 90 days away' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => (today + 90).to_s
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            }
          }
        }
      end

      it 'bdd_qualified is true' do
        expect(subject.send(:bdd_qualified?)).to be true
      end

      context 'when only gurard/reserves' do
        let(:form_content) do
          {
            'form526' => {
              'serviceInformation' => {
                'servicePeriods' => [
                  {
                    'dateRange' => {
                      'from' => '1980-02-05',
                      'to' => (today + 100).to_s
                    },
                    'serviceBranch' => 'Air National Guard'
                  }
                ]
              }
            }
          }
        end

        it 'bdd_qualified is true' do
          expect(subject.send(:bdd_qualified?)).to be false
        end
      end

      context 'activated in guard' do
        let(:form_content) do
          {
            'form526' => {
              'serviceInformation' => {
                'reservesNationalGuardService' => {
                  'title10Activation' => {
                    'anticipatedSeparationDate' => (today + 100).to_s,
                    'title10ActivationDate' => '2015-01-01'
                  }
                },
                'servicePeriods' => [
                  {
                    'dateRange' => {
                      'from' => '1980-02-05',
                      'to' => '2120-01-01'
                    },
                    'serviceBranch' => 'Air National Guard'
                  }
                ]
              }
            }
          }
        end

        it 'bdd_qualified is true' do
          expect(subject.send(:bdd_qualified?)).to be true
        end
      end
    end

    context 'when rad date is < 90 days away' do
      let(:form_content) do
        {
          'form526' => {
            'serviceInformation' => {
              'servicePeriods' => [
                {
                  'dateRange' => {
                    'from' => '1980-02-05',
                    'to' => (today + 89).to_s
                  },
                  'serviceBranch' => 'Air Force'
                }
              ]
            }
          }
        }
      end

      it 'bdd_qualified is false' do
        expect(subject.send(:bdd_qualified?)).to be false
      end
    end
  end
end
