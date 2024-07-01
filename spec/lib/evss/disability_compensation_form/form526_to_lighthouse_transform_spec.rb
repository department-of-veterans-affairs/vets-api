# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form526_to_lighthouse_transform'

RSpec.describe EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform do
  let(:transformer) { subject }

  describe '#transform' do
    let(:submission) { create(:form526_submission, :with_everything_toxic_exposure) }
    let(:data) { submission.form['form526'] }

    it 'sets claimant_certification to true in the Lighthouse request body' do
      lh_request_body = transformer.transform(data)
      expect(lh_request_body.claimant_certification).to be(true)
    end

    # TODO: re-visit once we get clarification on whether claimDate needs to be restored to LH request
    # context 'when claim_date is provided' do
    #   let(:claim_date) { Date.new(2023, 7, 19).strftime('%Y-%m-%d') }
    #
    #   it 'sets claim_date in the Lighthouse request body' do
    #     data['form526']['claimDate'] = claim_date
    #     lh_request_body = transformer.transform(data)
    #     expect(lh_request_body.claim_date).to eq(claim_date)
    #   end
    # end

    it 'verify the LH request body is being populated correctly by default' do
      expect(transformer).to receive(:evss_claims_process_type)
        .with(data['form526'])
        .and_return('STANDARD_CLAIM_PROCESS')
      result = transformer.transform(data)

      expect(result.claimant_certification).to eq(true)
      expect(result.claim_process_type).to eq('STANDARD_CLAIM_PROCESS')
      expect(result.veteran_identification.class).to eq(Requests::VeteranIdentification)

      expect(result.change_of_address.class).to eq(Requests::ChangeOfAddress)
      expect(result.change_of_address.dates.begin_date).to eq('2018-02-01')
      expect(result.change_of_address.dates.end_date).to eq('2018-06-30')

      expect(result.homeless.class).to eq(Requests::Homeless)
      expect(result.service_information.class).to eq(Requests::ServiceInformation)
      expect(result.disabilities.first.class).to eq(Requests::Disability)
      expect(result.direct_deposit.class).to eq(Requests::DirectDeposit)
      expect(result.treatments.first.class).to eq(Requests::Treatment)
      expect(result.service_pay.class).to eq(Requests::ServicePay)
      expect(result.toxic_exposure.class).to eq(Requests::ToxicExposure)
      expect(result.toxic_exposure.gulf_war_hazard_service.class).to eq(Requests::GulfWarHazardService)
      expect(result.toxic_exposure.herbicide_hazard_service.class).to eq(Requests::HerbicideHazardService)
      expect(result.toxic_exposure.additional_hazard_exposures.class).to eq(Requests::AdditionalHazardExposures)
      expect(result.toxic_exposure.multiple_exposures.class).to eq(Array)
    end
  end

  describe 'optional request objects are correctly rendered' do
    let(:submission) { create(:form526_submission, :only_526_required) }
    let(:data) { submission.form['form526'] }

    it 'renders JSON correctly when missing optional sections' do
      result = transformer.transform(data)
      expect(result.change_of_address).to be_nil
      expect(result.homeless).to be_nil
      expect(result.direct_deposit).to be_nil
      expect(result.treatments).to eq([])
      expect(result.service_pay).to be_nil
    end
  end

  describe '#evss_claims_process_type' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526'] }

    it 'returns "FDC_PROGRAM" by default' do
      data['form526']['bddQualified'] = false
      data['form526']['standardClaim'] = false
      result = transformer.send(:evss_claims_process_type, data['form526'])
      expect(result).to eq('FDC_PROGRAM')
    end

    it 'sets claimsProcessType to STANDARD_CLAIM_PROCESS in the Lighthouse request body' do
      data['form526']['bddQualified'] = false
      data['form526']['standardClaim'] = true
      result = transformer.send(:evss_claims_process_type, data['form526'])
      expect(result).to eq('STANDARD_CLAIM_PROCESS')
    end

    it 'sets claimsProcessType to BDD_PROGRAM in the Lighthouse request body' do
      data['form526']['bddQualified'] = true
      data['form526']['standardClaim'] = false
      result = transformer.send(:evss_claims_process_type, data['form526'])
      expect(result).to eq('BDD_PROGRAM')
    end

    it 'sets claimsProcessType to BDD_PROGRAM in the Lighthouse request body, even if standardClaim is also true' do
      data['form526']['bddQualified'] = true
      data['form526']['standardClaim'] = true
      result = transformer.send(:evss_claims_process_type, data['form526'])
      expect(result).to eq('BDD_PROGRAM')
    end
  end

  describe 'transform veteran identification' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526'] }

    it 'sets veteran identification correctly' do
      result = transformer.send(:transform_veteran, data['form526']['veteran'])
      expect(result.current_va_employee).to eq(false)
      expect(result.email_address).not_to be_nil
      expect(result.veteran_number).not_to be_nil
      expect(result.mailing_address).not_to be_nil
    end

    it 'sets military/intl address correctly' do
      data['form526']['veteran']['currentMailingAddress']['militaryPostOfficeTypeCode'] = 'APO'
      data['form526']['veteran']['currentMailingAddress']['militaryStateCode'] = 'AE'
      data['form526']['veteran']['currentMailingAddress']['internationalPostalCode'] = '817'

      result = transformer.send(:transform_veteran, data['form526']['veteran'])
      expect(result.mailing_address.city).to eq('APO')
      expect(result.mailing_address.state).to eq('AE')
      expect(result.mailing_address.zip_first_five).to eq('817')
    end
  end

  describe 'transform change of address' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526'] }

    it 'sets change of address correctly' do
      result = transformer.send(:transform_change_of_address, data['form526']['veteran'])
      expect(result.city).to eq('Portland')
      expect(result.dates).not_to be_nil
    end

    it 'sets military/intl address correctly' do
      data['form526']['veteran']['changeOfAddress']['militaryPostOfficeTypeCode'] = 'APO'
      data['form526']['veteran']['changeOfAddress']['militaryStateCode'] = 'AE'
      data['form526']['veteran']['changeOfAddress']['internationalPostalCode'] = '817'

      result = transformer.send(:transform_change_of_address, data['form526']['veteran'])
      expect(result.city).to eq('APO')
      expect(result.state).to eq('AE')
      expect(result.zip_first_five).to eq('817')
      expect(result.dates).not_to be_nil
    end
  end

  describe 'transform homeless' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526'] }

    it 'sets change of address correctly' do
      result = transformer.send(:transform_homeless, data['form526']['veteran'])
      expect(result.point_of_contact).to eq('Jane Doe')
      expect(result.currently_homeless).not_to be_nil
      expect(result.risk_of_becoming_homeless).to be_nil
      expect(result.point_of_contact_number).not_to be_nil
    end
  end

  describe 'transform service information' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526']['form526']['serviceInformation'] }

    it 'sets service information correctly' do
      result = transformer.send(:transform_service_information, data)
      expect(result.service_periods).not_to be_nil
      expect(result.confinements).not_to be_nil
      expect(result.alternate_names).not_to be_nil
      expect(result.reserves_national_guard_service).not_to be_nil
      expect(result.reserves_national_guard_service.receiving_inactive_duty_training_pay).to be('YES')
      expect(result.service_periods.first.separation_location_code).to eq('OU812')
      expect(result.reserves_national_guard_service.component).to eq('Reserves')
    end

    it 'converts service branch to service component correctly' do
      result = transformer.send(:convert_to_service_component, 'Air Force Reserves')
      expect(result).to eq('Reserves')
      result = transformer.send(:convert_to_service_component, 'Army National Guard')
      expect(result).to eq('National Guard')
      result = transformer.send(:convert_to_service_component, 'Space Force')
      expect(result).to eq('Active')
    end
  end

  describe 'transform disabilities' do
    let(:submission) { create(:form526_submission, :with_everything_toxic_exposure) }
    let(:data) { submission.form['form526']['form526']['disabilities'] }
    let(:submission_without_te) { create(:form526_submission, :with_everything) }
    let(:data_without_te) { submission_without_te.form['form526']['form526']['disabilities'] }

    it 'sets disabilities correctly' do
      results = transformer.send(:transform_disabilities, data_without_te, nil)
      expect(results.length).to eq(1)
      expect(results.first.exposure_or_event_or_injury).to eq(nil)
      expect(results.first.is_related_to_toxic_exposure).to eq(nil)
    end

    it 'converts approximate dates' do
      result = transformer.send(:convert_approximate_date,
                                JSON.parse({ month: '03', day: '22', year: '1973' }.to_json))
      expect(result).to eq('1973-03-22')
      result = transformer.send(:convert_approximate_date, JSON.parse({ month: '03', year: '1973' }.to_json))
      expect(result).to eq('1973-03')
    end

    it 'sets the is related to toxic exposure flag when matching to TE conditions' do
      toxic_exposure_conditions = submission.form['form526']['form526']['toxicExposure']['conditions']
      results = transformer.send(:transform_disabilities, data, toxic_exposure_conditions)
      expect(results.first.is_related_to_toxic_exposure).to eq(true)
      expect(results.last.is_related_to_toxic_exposure).to eq(false)
    end

    it 'sets the exposure or event or injury according to the cause' do
      toxic_exposure_conditions = submission.form['form526']['form526']['toxicExposure']['conditions']
      results = transformer.send(:transform_disabilities, data, toxic_exposure_conditions)
      cause_map = EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform::TOXIC_EXPOSURE_CAUSE_MAP
      expect(results.first.exposure_or_event_or_injury).to eq(cause_map[:VA])
      expect(results[1].exposure_or_event_or_injury).to eq(cause_map[:NEW])
      expect(results[2].exposure_or_event_or_injury).to eq(cause_map[:WORSENED])
      expect(results.last.exposure_or_event_or_injury).to eq(cause_map[:SECONDARY])
    end
  end

  describe 'transform direct deposit' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526']['form526']['directDeposit'] }

    it 'sets direct deposit correctly' do
      result = transformer.send(:transform_direct_deposit, data)
      expect(result.financial_institution_name).to eq('SomeBank')
      expect(result.account_type).to eq('CHECKING')
      expect(result.account_number).to eq('123123123123')
      expect(result.routing_number).to eq('123123123')
    end
  end

  describe 'transform treatments' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526']['form526']['treatments'] }

    it 'sets treatments correctly' do
      result = transformer.send(:transform_treatments, data)
      expect(result.length).to eq(2)
      expect(result.first.class).to eq(Requests::Treatment)
      expect(result.first.treated_disability_names).to eq(['PTSD (post traumatic stress disorder)'])
    end
  end

  describe 'transform service pay' do
    let(:submission) { create(:form526_submission, :with_everything) }
    let(:data) { submission.form['form526']['form526']['servicePay'] }

    it 'sets service pay correctly' do
      result = transformer.send(:transform_service_pay, data)
      expect(result.favor_training_pay).to eq(true)
      expect(result.favor_military_retired_pay).to eq(false)
      expect(result.receiving_military_retired_pay).to eq('YES')
      expect(result.future_military_retired_pay).to eq('NO')

      # military retired mappings
      expect(result.military_retired_pay.class).to eq(Requests::MilitaryRetiredPay)
      expect(result.military_retired_pay.branch_of_service).to eq('Air Force')
      expect(result.military_retired_pay.monthly_amount).to eq(500.00)

      # separation severance pay mappings
      expect(result.retired_status).to eq('RETIRED')
      expect(result.received_separation_or_severance_pay).to eq('YES')
      expect(result.separation_severance_pay.class).to eq(Requests::SeparationSeverancePay)
      expect(result.separation_severance_pay.date_payment_received).to eq('2000')
      expect(result.separation_severance_pay.branch_of_service).to eq('Air Force')
      expect(result.separation_severance_pay.pre_tax_amount_received).to eq(1000.00)
    end
  end

  describe 'transform toxic exposure' do
    let(:submission) { create(:form526_submission, :with_everything_toxic_exposure) }
    let(:data) { submission.form['form526']['form526']['toxicExposure'] }

    it 'set served_in_gulf_war_hazard_locations correctly' do
      result = transformer.send(:transform_toxic_exposure, data)
      expect(result.gulf_war_hazard_service.served_in_gulf_war_hazard_locations).to eq('YES')

      with_none_of_these_option = data.merge({
                                               'gulfWar1990' => {
                                                 'none' => true
                                               },
                                               'gulfWar2001' => {
                                                 'none' => true
                                               }
                                             })
      result = transformer.send(:transform_toxic_exposure, with_none_of_these_option)
      expect(result.gulf_war_hazard_service.served_in_gulf_war_hazard_locations).to eq('NO')

      falsified_options = data.merge({
                                       'gulfWar1990' => {
                                         'iraq' => false,
                                         'kuwait' => false,
                                         'qatar' => false,
                                         'none' => false
                                       },
                                       'gulfWar2001' => {
                                         'djibouti' => false,
                                         'lebanon' => false,
                                         'uzbekistan' => false,
                                         'yemen' => false,
                                         'airspace' => false,
                                         'none' => false
                                       }
                                     })
      result = transformer.send(:transform_toxic_exposure, falsified_options)
      expect(result.gulf_war_hazard_service.served_in_gulf_war_hazard_locations).to eq('NO')

      falsified_gulf_war_1990_options = data.merge({
                                                     'gulfWar1990' => {
                                                       'iraq' => false,
                                                       'kuwait' => false,
                                                       'qatar' => false
                                                     }
                                                   })
      result = transformer.send(:transform_toxic_exposure, falsified_gulf_war_1990_options)
      expect(result.gulf_war_hazard_service.served_in_gulf_war_hazard_locations).to eq('YES')

      no_options = data.merge({
                                'gulfWar1990' => {},
                                'gulfWar2001' => {}
                              })
      result = transformer.send(:transform_toxic_exposure, no_options)
      expect(result.gulf_war_hazard_service).to be_nil

      one_has_no_options = data.merge({
                                        'gulfWar1990' => {
                                          'iraq' => true,
                                          'kuwait' => true,
                                          'qatar' => true
                                        },
                                        'gulfWar2001' => nil
                                      })
      result = transformer.send(:transform_toxic_exposure, one_has_no_options)
      expect(result.gulf_war_hazard_service.served_in_gulf_war_hazard_locations).to eq('YES')
    end

    it 'transforms gulf war, herbicide and hazard multiple exposure dates' do
      result = transformer.send(:transform_multiple_exposures, data['gulfWar1990Details'])
      expect(result[0].exposure_dates.begin_date).to eq('1991-03')
      expect(result[0].exposure_dates.end_date).to eq('1992-01')
      expect(result[0].exposure_location).to eq('Iraq')

      result = transformer.send(:transform_multiple_exposures, data['herbicideDetails'],
                                EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform::
                                    MULTIPLE_EXPOSURES_TYPE[:herbicide])
      expect(result[0].exposure_dates.begin_date).to eq('1991-03')
      expect(result[0].exposure_dates.end_date).to eq('1992-01')
      expect(result[0].exposure_location).to eq('Cambodia at Mimot or Krek, Kampong Cham Province')

      result = transformer.send(:transform_multiple_exposures_other_details, data['otherHerbicideLocations'],
                                EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform::
                                    MULTIPLE_EXPOSURES_TYPE[:herbicide])
      expect(result[0].exposure_dates.begin_date).to eq('1991-03')
      expect(result[0].exposure_dates.end_date).to eq('1992-01')
      expect(result[0].exposure_location).to eq('other location 1, other location 2 etc')

      result = transformer.send(:transform_multiple_exposures, data['otherExposuresDetails'],
                                EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform::
                                    MULTIPLE_EXPOSURES_TYPE[:hazard])
      expect(result[0].exposure_dates.begin_date).to eq('1991-03')
      expect(result[0].exposure_dates.end_date).to eq('1992-01')
      expect(result[0].hazard_exposed_to).to eq('Asbestos')

      result = transformer.send(:transform_multiple_exposures_other_details, data['specifyOtherExposures'],
                                EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform::
                                    MULTIPLE_EXPOSURES_TYPE[:hazard])
      expect(result[0].exposure_dates.begin_date).to eq('1991-03')
      expect(result[0].exposure_dates.end_date).to eq('1992-01')
      expect(result[0].hazard_exposed_to).to eq('Lead, burn pits')

      no_location_dates = data.merge({
                                       'gulfWar1990Details' => {
                                         'iraq' => {}
                                       }
                                     })
      result = transformer.send(:transform_multiple_exposures, no_location_dates['gulfWar1990Details'])
      expect(result[0].exposure_dates.begin_date).to be_nil
      expect(result[0].exposure_dates.end_date).to be_nil
      expect(result[0].exposure_location).to eq('Iraq')

      no_location_details = data.merge({
                                         'gulfWar1990Details' => {}
                                       })
      result = transformer.send(:transform_multiple_exposures, no_location_details['gulfWar1990Details'])
      expect(result.length).to eq(0)
    end

    it 'set served_in_herbicide_hazard_locations correctly' do
      result = transformer.send(:transform_herbicide, data['herbicide'], nil)
      expect(result.served_in_herbicide_hazard_locations).to eq('YES')

      with_none_of_these_option = data.merge({
                                               'herbicide' => {
                                                 'none' => true
                                               }
                                             })
      result = transformer.send(:transform_herbicide, with_none_of_these_option['herbicide'], nil)
      expect(result.served_in_herbicide_hazard_locations).to eq('NO')

      falsified_options = data.merge({
                                       'herbicide' => {
                                         'cambodia' => false,
                                         'guam' => false,
                                         'laos' => false,
                                         'none' => false
                                       }
                                     })
      result = transformer.send(:transform_herbicide, falsified_options['herbicide'], nil)
      expect(result.served_in_herbicide_hazard_locations).to eq('NO')

      herbicide_has_no_options = data.merge({
                                              'herbicide' => {
                                                'cambodia' => true,
                                                'guam' => true,
                                                'laos' => true
                                              },
                                              'otherHerbicideLocations' => nil
                                            })
      result = transformer.send(:transform_herbicide, herbicide_has_no_options['herbicide'],
                                falsified_options['otherHerbicideLocations'])
      expect(result.served_in_herbicide_hazard_locations).to eq('YES')

      other_herbicide_has_no_options = data.merge({
                                                    'herbicide' => nil,
                                                    'otherHerbicideLocations' => {
                                                      'description' => 'other location 1, other location 2 etc',
                                                      'startDate' => '1991-03-01',
                                                      'endDate' => '1992-01-01'
                                                    }
                                                  })
      result = transformer.send(:transform_herbicide, other_herbicide_has_no_options['herbicide'],
                                falsified_options['otherHerbicideLocations'])
      expect(result.served_in_herbicide_hazard_locations).to eq('YES')

      other_herbicide_locations_has_null_fields = data.merge({
                                                               'herbicide' => nil,
                                                               'otherHerbicideLocations' => {
                                                                 'description' => nil,
                                                                 'startDate' => nil,
                                                                 'endDate' => nil
                                                               }
                                                             })
      result = transformer.send(:transform_herbicide, other_herbicide_locations_has_null_fields['herbicide'],
                                other_herbicide_locations_has_null_fields['otherHerbicideLocations'])
      expect(result.served_in_herbicide_hazard_locations).to eq('NO')

      other_herbicide_locations_has_blank_fields = data.merge({
                                                                'herbicide' => nil,
                                                                'otherHerbicideLocations' => {
                                                                  'description' => '',
                                                                  'startDate' => '',
                                                                  'endDate' => ''
                                                                }
                                                              })
      result = transformer.send(:transform_herbicide, other_herbicide_locations_has_blank_fields['herbicide'],
                                other_herbicide_locations_has_blank_fields['otherHerbicideLocations'])
      expect(result.served_in_herbicide_hazard_locations).to eq('NO')
    end

    it 'set additional_hazard_exposures correctly' do
      result = transformer.send(:transform_other_exposures, data['otherExposures'], data['specifyOtherExposures'])
      expect(result.additional_exposures.length).to eq(3)
      expect(result.additional_exposures[0]).to eq('ASBESTOS')
      expect(result.additional_exposures[1]).to eq('RADIATION')
      expect(result.additional_exposures[2]).to eq('OTHER')

      some_options_set_to_false = data.merge({
                                               'otherExposures' => {
                                                 'asbestos' => true,
                                                 'radiation' => false
                                               },
                                               'specifyOtherExposures' => {
                                                 'description' => 'Lead, burn pits',
                                                 'startDate' => '1991-03-01',
                                                 'endDate' => '1992-01-01'
                                               }
                                             })
      result = transformer.send(:transform_other_exposures, some_options_set_to_false['otherExposures'],
                                some_options_set_to_false['specifyOtherExposures'])
      expect(result.additional_exposures.length).to eq(2)
      expect(result.additional_exposures[0]).to eq('ASBESTOS')
      expect(result.additional_exposures[1]).to eq('OTHER')

      all_options_set_to_false = data.merge({
                                              'otherExposures' => {
                                                'asbestos' => false,
                                                'radiation' => false
                                              },
                                              'specifyOtherExposures' => {
                                                'description' => 'Lead, burn pits',
                                                'startDate' => '1991-03-01',
                                                'endDate' => '1992-01-01'
                                              }
                                            })
      result = transformer.send(:transform_other_exposures, all_options_set_to_false['otherExposures'],
                                all_options_set_to_false['specifyOtherExposures'])
      expect(result.additional_exposures.length).to eq(1)
      expect(result.additional_exposures[0]).to eq('OTHER')

      all_options_nil_and_other_partial = data.merge({
                                                       'otherExposures' => nil,
                                                       'specifyOtherExposures' => {
                                                         'description' => 'Lead, burn pits',
                                                         'startDate' => '',
                                                         'endDate' => ''
                                                       }
                                                     })
      result = transformer.send(:transform_other_exposures, all_options_nil_and_other_partial['otherExposures'],
                                all_options_nil_and_other_partial['specifyOtherExposures'])
      expect(result.additional_exposures.length).to eq(1)
      expect(result.additional_exposures[0]).to eq('OTHER')

      all_options_nil_and_other_blank = data.merge({
                                                     'otherExposures' => nil,
                                                     'specifyOtherExposures' => {
                                                       'description' => '',
                                                       'startDate' => '',
                                                       'endDate' => ''
                                                     }
                                                   })
      result = transformer.send(:transform_other_exposures, all_options_nil_and_other_blank['otherExposures'],
                                all_options_nil_and_other_blank['specifyOtherExposures'])
      expect(result).to eq(nil)

      all_nil = data.merge({
                             'otherExposures' => nil,
                             'specifyOtherExposures' => nil
                           })
      result = transformer.send(:transform_other_exposures, all_nil['otherExposures'],
                                all_nil['specifyOtherExposures'])
      expect(result).to eq(nil)

      none_option_with_other = data.merge({
                                            'otherExposures' => {
                                              'asbestos' => true,
                                              'radiation' => true,
                                              'none' => true
                                            },
                                            'specifyOtherExposures' => {
                                              'description' => 'Lead, burn pits',
                                              'startDate' => '1991-03-01',
                                              'endDate' => '1992-01-01'
                                            }
                                          })
      result = transformer.send(:transform_other_exposures, none_option_with_other['otherExposures'],
                                none_option_with_other['specifyOtherExposures'])
      expect(result.additional_exposures.length).to eq(1)
      expect(result.additional_exposures[0]).to eq('OTHER')

      none_option_with_no_other = data.merge({
                                               'otherExposures' => {
                                                 'asbestos' => true,
                                                 'radiation' => true,
                                                 'none' => true
                                               },
                                               'specifyOtherExposures' => {}
                                             })
      result = transformer.send(:transform_other_exposures, none_option_with_no_other['otherExposures'],
                                none_option_with_no_other['specifyOtherExposures'])
      expect(result).to eq(nil)
    end
  end
end
