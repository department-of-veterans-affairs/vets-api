# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'

RSpec.describe DecisionReviews::V1::SupplementalClaimsController, type: :controller do
  routes { DecisionReviews::Engine.routes }

  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#format_evidence_data_for_lighthouse_schema' do
    before do
      allow(Flipper).to receive(:enabled?).with(:decision_review_sc_redesign_nov2025).and_return(true)
    end

    context 'when the redesign flipper is on, and there is uploaded evidence and VA evidence' do
      subject(:transformed_data) { controller.send(:format_evidence_data_for_lighthouse_schema, req_body_obj) }

      let(:req_body_obj) do
        {
          'scRedesign' => true,
          'data' => {
            'type' => 'supplementalClaim',
            'attributes' => {
              'benefitType' => 'compensation',
              'claimantType' => 'veteran',
              'homeless' => false,
              'veteran' => {
                'timezone' => 'America/Chicago',
                'address' => {
                  'addressLine1' => '123 Mailing Address St.',
                  'addressLine2' => 'Apt 1',
                  'city' => 'Fulton',
                  'stateCode' => 'NY',
                  'countryCodeISO2' => 'US',
                  'zipCode5' => '97063'
                },
                'phone' => {
                  'countryCode' => '1',
                  'areaCode' => '989',
                  'phoneNumber' => '8981233'
                },
                'email' => 'myemail72585885@unattended.com'
              },
              'treatmentLocations' => [
                'VA MEDICAL CENTERS (VAMC) AND COMMUNITY-BASED OUTPATIENT CLINICS (CBOC)',
                'PRIVATE HEALTH CARE PROVIDER'
              ],
              'socOptIn' => true,
              'vaEvidence' => [
                {
                  'treatmentBefore2005' => 'N',
                  'issuesVA' => {
                    'Left Knee Instability' => true,
                    'Right Knee Injury' => true
                  },
                  'vaTreatmentLocation' => 'Midwest Alabama VA Facility'
                },
                {
                  'treatmentBefore2005' => 'Y',
                  'treatmentMonthYear' => '2000-05',
                  'issuesVA' => {
                    'Hypertension' => true,
                    'Impotence' => true
                  },
                  'vaTreatmentLocation' => 'Southwest Georgia VA Facility'
                }
              ]
            }
          },
          'included' => [
            {
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'Hypertension - 0% - Service connection for hypertension is denied.',
                'decisionDate' => '2023-09-26',
                'ratingIssueReferenceId' => '8891'
              }
            },
            {
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'Impotence - 0% - Evaluation of impotence, which is currently 0% disabling, is continued.',
                'decisionDate' => '2023-09-26',
                'ratingIssueReferenceId' => '7902'
              }
            },
            {
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'Left Knee Instability - 10% - Evaluation of left knee instability, which is currently 10% disabling, is increased to 10% effective February 13',
                'decisionDate' => '2023-09-26',
                'ratingIssueReferenceId' => '7952'
              }
            },
            {
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'Right Knee Injury - 30% - Evaluation of right knee injury, which is currently 30% disabling, is continued.',
                'decisionDate' => '2023-09-26',
                'ratingIssueReferenceId' => '7884'
              }
            }
          ],
          'form4142' => {
            'authorization' => true,
            'lcPrompt' => 'N',
            'evidenceEntries' => [
              'treatmentStart' => '2012-10-11',
              'treatmentEnd' => '2012-10-12',
              'issuesPrivate' => {
                'Hypertension' => true,
                'Impotence' => true,
                'Left Knee Instability' => true
              },
              'privateTreatmentLocation' => 'South Texas VA Facility',
              'address' => {
                'view:militaryBaseDescription' => {},
                'country' => 'USA',
                'street' => '123 Main Street',
                'street2' => 'Street address 2',
                'city' => 'San Antonio',
                'state' => 'TX',
                'postalCode' => '78258'
              }
            ]
          },
          'additionalDocuments' => [{
            'name' => 'document.pdf',
            'size' => 123,
            'confirmationCode' => '123-456-789',
            'attachmentId' => 'L123',
            'isEncrypted' => false
          }]
        }
      end

      let(:expected_result) do
        {
          'scRedesign' => true,
          'data' => {
            'type' => 'supplementalClaim',
            'attributes' => {
              'benefitType' => 'compensation',
              'claimantType' => 'veteran',
              'homeless' => false,
              'veteran' => {
                'timezone' => 'America/Chicago',
                'address' => {
                  'addressLine1' => '123 Mailing Address St.',
                  'addressLine2' => 'Apt 1',
                  'city' => 'Fulton',
                  'stateCode' => 'NY',
                  'countryCodeISO2' => 'US',
                  'zipCode5' => '97063'
                },
                'phone' => {
                  'countryCode' => '1',
                  'areaCode' => '989',
                  'phoneNumber' => '8981233'
                },
                'email' => 'myemail72585885@unattended.com'
              },
              'evidenceSubmission' => {
                'evidenceType' => %w[retrieval upload],
                'treatmentLocations' => [
                  'VA MEDICAL CENTERS (VAMC) AND COMMUNITY-BASED OUTPATIENT CLINICS (CBOC)',
                  'PRIVATE HEALTH CARE PROVIDER'
                ],
                'retrieveFrom' => [
                  {
                    'type' => 'retrievalEvidence',
                    'attributes' => {
                      'locationAndName' => 'Midwest Alabama VA Facility',
                      'noTreatmentDates' => true
                    }
                  },
                  {
                    'type' => 'retrievalEvidence',
                    'attributes' => {
                      'locationAndName' => 'Southwest Georgia VA Facility',
                      'noTreatmentDates' => false,
                      'evidenceDates' => [{
                        'startDate' => '2000-05-01',
                        'endDate' => '2000-05-01'
                      }]
                    }
                  }
                ]
              },
              'socOptIn' => true
            }
          },
          'included' => [
            {
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'Hypertension - 0% - Service connection for hypertension is denied.',
                'decisionDate' => '2023-09-26',
                'ratingIssueReferenceId' => '8891'
              }
            },
            {
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'Impotence - 0% - Evaluation of impotence, which is currently 0% disabling, is continued.',
                'decisionDate' => '2023-09-26',
                'ratingIssueReferenceId' => '7902'
              }
            },
            {
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'Left Knee Instability - 10% - Evaluation of left knee instability, which is currently 10% disabling, is increased to 10% effective February 13',
                'decisionDate' => '2023-09-26',
                'ratingIssueReferenceId' => '7952'
              }
            },
            {
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'Right Knee Injury - 30% - Evaluation of right knee injury, which is currently 30% disabling, is continued.',
                'decisionDate' => '2023-09-26',
                'ratingIssueReferenceId' => '7884'
              }
            }
          ],
          'form4142' => {
            'authorization' => true,
            'lcPrompt' => 'N',
            'evidenceEntries' => [
              {
                'treatmentStart' => '2012-10-11',
                'treatmentEnd' => '2012-10-12',
                'issuesPrivate' => {
                  'Hypertension' => true,
                  'Impotence' => true,
                  'Left Knee Instability' => true
                },
                'privateTreatmentLocation' => 'South Texas VA Facility',
                'address' => {
                  'view:militaryBaseDescription' => {},
                  'country' => 'USA',
                  'street' => '123 Main Street',
                  'street2' => 'Street address 2',
                  'city' => 'San Antonio',
                  'state' => 'TX',
                  'postalCode' => '78258'
                }
              }
            ]
          },
          'additionalDocuments' => [{
            'name' => 'document.pdf',
            'size' => 123,
            'confirmationCode' => '123-456-789',
            'attachmentId' => 'L123',
            'isEncrypted' => false
          }]
        }
      end

      it 'transforms the payload correctly' do
        expect(transformed_data).to eq(expected_result)
      end
    end
  end

  describe '#normalize_evidence_retrieval_for_lighthouse_schema' do
    subject(:normalized_data) { controller.send(:normalize_evidence_retrieval_for_lighthouse_schema, req_body_obj) }

    context 'when retrieveFrom is an array with no duplicates' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'evidenceSubmission' => {
                'evidenceType' => ['retrieval'],
                'retrieveFrom' => [
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Boston',
                      'evidenceDates' => [
                        { 'startDate' => '2005-01', 'endDate' => '2005-01' }
                      ]
                    }
                  },
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Philadelphia',
                      'evidenceDates' => [
                        { 'startDate' => '2004-01', 'endDate' => '2004-01' }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      end

      it 'returns the original array unchanged' do
        expect(normalized_data).to eq(req_body_obj)
      end
    end

    context 'when retrieveFrom has duplicate locations' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'evidenceSubmission' => {
                'evidenceType' => ['retrieval'],
                'retrieveFrom' => [
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Boston',
                      'evidenceDates' => [
                        { 'startDate' => '2005-01', 'endDate' => '2005-01' }
                      ]
                    }
                  },
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Boston',
                      'evidenceDates' => [
                        { 'startDate' => '2004-01', 'endDate' => '2004-01' }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      end

      let(:expected_result) do
        {
          'data' => {
            'attributes' => {
              'evidenceSubmission' => {
                'evidenceType' => ['retrieval'],
                'retrieveFrom' => [
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Boston',
                      'evidenceDates' => [
                        { 'startDate' => '2004-01', 'endDate' => '2004-01' },
                        { 'startDate' => '2005-01', 'endDate' => '2005-01' }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      end

      it 'merges entries with the same location' do
        expect(normalized_data).to eq(expected_result)
      end
    end
  end

  describe '#merge_evidence_entries' do
    subject(:merged_entry) { controller.send(:merge_evidence_entries, entries) }

    context 'when entries have different evidence dates' do
      let(:entries) do
        [
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2005-01', 'endDate' => '2005-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2004-01', 'endDate' => '2004-01' }
              ]
            }
          }
        ]
      end

      let(:expected_result) do
        {
          'attributes' => {
            'locationAndName' => 'VA Medical Center - Boston',
            'evidenceDates' => [
              { 'startDate' => '2004-01', 'endDate' => '2004-01' },
              { 'startDate' => '2005-01', 'endDate' => '2005-01' }
            ]
          }
        }
      end

      it 'combines all evidence dates in chronological order' do
        expect(merged_entry).to eq(expected_result)
      end
    end

    context 'when entries have duplicate evidence dates' do
      let(:entries) do
        [
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2005-01', 'endDate' => '2005-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2005-01', 'endDate' => '2005-01' }
              ]
            }
          }
        ]
      end

      let(:expected_result) do
        {
          'attributes' => {
            'locationAndName' => 'VA Medical Center - Boston',
            'evidenceDates' => [
              { 'startDate' => '2005-01', 'endDate' => '2005-01' }
            ]
          }
        }
      end

      it 'removes duplicate evidence dates' do
        expect(merged_entry).to eq(expected_result)
      end
    end

    context 'when there are more than 4 evidence dates from multiple entries' do
      let(:entries) do
        [
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2005-01', 'endDate' => '2005-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2004-01', 'endDate' => '2004-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2003-01', 'endDate' => '2003-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2001-01', 'endDate' => '2001-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2024-01', 'endDate' => '2024-01' }
              ]
            }
          }
        ]
      end

      let(:expected_result) do
        {
          'attributes' => {
            'locationAndName' => 'VA Medical Center - Boston',
            'evidenceDates' => [
              { 'startDate' => '2001-01', 'endDate' => '2001-01' },
              { 'startDate' => '2003-01', 'endDate' => '2003-01' },
              { 'startDate' => '2004-01', 'endDate' => '2004-01' },
              { 'startDate' => '2005-01', 'endDate' => '2005-01' }
            ]
          }
        }
      end

      it 'limits to the first 4 evidence dates' do
        expect(merged_entry).to eq(expected_result)
        expect(merged_entry['attributes']['evidenceDates'].length).to eq(4)
      end
    end

    context 'when entries have nil evidenceDates' do
      let(:entries) do
        [
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => nil
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2004-01', 'endDate' => '2004-01' }
              ]
            }
          }
        ]
      end

      let(:expected_result) do
        {
          'attributes' => {
            'locationAndName' => 'VA Medical Center - Boston',
            'evidenceDates' => [
              { 'startDate' => '2004-01', 'endDate' => '2004-01' }
            ]
          }
        }
      end

      it 'handles nil evidence dates gracefully' do
        expect(merged_entry).to eq(expected_result)
      end
    end

    context 'when entries have do not have evidenceDates' do
      let(:entries) do
        [
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'noTreatmentDates' => true
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'noTreatmentDates' => true
            }
          }
        ]
      end

      let(:expected_result) do
        {
          'attributes' => {
            'locationAndName' => 'VA Medical Center - Boston',
            'noTreatmentDates' => true
          }
        }
      end

      it 'handles missing evidence dates gracefully' do
        expect(merged_entry).to eq(expected_result)
      end
    end
  end
end
