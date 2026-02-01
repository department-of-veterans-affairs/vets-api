# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../fixtures/form_profile/va_686c674_spec_data'
require 'bgs/dependent_service'

RSpec.describe FormProfile, type: :model do
  include SchemaMatchers

  before do
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:dependents_module_enabled, anything).and_return(true)
    described_class.instance_variable_set(:@mappings, nil)
  end

  let(:user) do
    build(:user, :loa3, :legacy_icn, idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef', suffix: 'Jr.',
                                     address: build(:va_profile_address), vet360_id: '1')
  end

  let(:form_profile) { described_class.new(form_id: 'foo', user:) }
  let(:contact_info) { form_profile.send :initialize_contact_information }
  let(:va_profile_address) { contact_info&.address }
  let(:us_phone) { contact_info&.home_phone }
  let(:mobile_phone) { contact_info&.mobile_phone }
  let(:full_name) do
    { 'first' => user.first_name&.capitalize,
      'middle' => user.middle_name&.capitalize,
      'last' => user.last_name&.capitalize,
      'suffix' => user.suffix }
  end
  let(:address) do
    {
      'street' => va_profile_address.street,
      'street2' => va_profile_address.street2,
      'city' => va_profile_address.city,
      'state' => va_profile_address.state,
      'country' => va_profile_address.country,
      'postal_code' => va_profile_address.postal_code
    }
  end

  let(:v686_c_674_v2_expected) { FormProfileSpecData.v686_c_674_v2_expected(user, us_phone) }
  let(:initialize_va_profile_prefill_military_information_expected) do
    FormProfileSpecData.initialize_va_profile_prefill_military_information_expected
  end
  let(:dependent_service) { instance_double(BGS::DependentService) }
  let(:dependents_data) { FormProfileSpecData.dependents_data }
  let(:dependents_information) { FormProfileSpecData.dependents_information }

  describe '#initialize_military_information', :skip_va_profile do
    context 'with military_information vaprofile' do
      it 'prefills military data from va profile' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                         allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
          output = form_profile.send(:initialize_military_information).attribute_values.transform_keys(&:to_s)

          expected_output = initialize_va_profile_prefill_military_information_expected
          expected_output['vic_verified'] = false

          actual_service_histories = output.delete('service_episodes_by_date')
          actual_guard_reserve_service_history = output.delete('guard_reserve_service_history')
          actual_latest_guard_reserve_service_period = output.delete('latest_guard_reserve_service_period')

          expected_service_histories = expected_output.delete('service_episodes_by_date')
          expected_guard_reserve_service_history = expected_output.delete('guard_reserve_service_history')
          expected_latest_guard_reserve_service_period = expected_output.delete('latest_guard_reserve_service_period')

          # Now that the nested structures are removed from the outputs, compare the rest of the structure.
          expect(output).to eq(expected_output)
          # Compare the nested structures VAProfile::Models::ServiceHistory objects separately.
          expect(actual_service_histories.map(&:attributes)).to match(expected_service_histories)

          first_item = actual_guard_reserve_service_history.map(&:attributes).first
          expect(first_item['from'].to_s).to eq(expected_guard_reserve_service_history.first[:from])
          expect(first_item['to'].to_s).to eq(expected_guard_reserve_service_history.first[:to])

          guard_period = actual_latest_guard_reserve_service_period.attributes.transform_keys(&:to_s)
          expect(guard_period['from'].to_s).to eq(expected_latest_guard_reserve_service_period[:from])
          expect(guard_period['to'].to_s).to eq(expected_latest_guard_reserve_service_period[:to])
        end
      end
    end
  end

  describe '#initialize_va_profile_prefill_military_information' do
    context 'when va profile is down in production' do
      it 'logs exception and returns empty hash' do
        expect(form_profile).to receive(:log_exception_to_rails)
        expect(form_profile.send(:initialize_va_profile_prefill_military_information)).to eq({})
      end
    end

    it 'prefills military data from va profile' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                       allow_playback_repeats: true, match_requests_on: %i[method body]) do
        output = form_profile.send(:initialize_va_profile_prefill_military_information)
        # Extract service_episodes_by_date and then compare their attributes
        actual_service_histories = output.delete('service_episodes_by_date')
        expected_service_histories = initialize_va_profile_prefill_military_information_expected
                                     .delete('service_episodes_by_date')

        # Now that service_episodes_by_date is removed from output and from
        # initialize_va_profile_prefill_military_information_expected, compare the rest of the structure.
        expect(output).to eq(initialize_va_profile_prefill_military_information_expected)

        # Compare service_episodes_by_date separately.
        # Convert each VAProfile::Models::ServiceHistory object to a hash of attributes so it can be
        # compared to the expected output.
        expect(actual_service_histories.map(&:attributes)).to match(expected_service_histories)
      end
    end
  end

  describe '#prefill_form' do
    def can_prefill_vaprofile(yes)
      expect(user).to receive(:authorize).at_least(:once).with(:va_profile, :access?).and_return(yes)
    end

    def strip_required(schema)
      new_schema = {}

      schema.each do |k, v|
        next if k == 'required'

        new_schema[k] = v.is_a?(Hash) ? strip_required(v) : v
      end

      new_schema
    end

    def expect_prefilled(form_id)
      prefilled_data = Oj.load(described_class.for(form_id:, user:).prefill.to_json)['form_data']

      schema = strip_required(VetsJsonSchema::SCHEMAS[form_id]).except('anyOf')
      schema_data = prefilled_data.deep_dup
      errors = JSON::Validator.fully_validate(
        schema,
        schema_data.deep_transform_keys { |key| key.camelize(:lower) }, validate_schema: true
      )

      expect(errors.empty?).to be(true), "schema errors: #{errors}"

      expect(prefilled_data).to eq(
        form_profile.send(:clean!, public_send("v#{form_id.underscore}_expected"))
      )
    end

    context 'when VA Profile returns 404', :skip_va_profile do
      it 'returns default values' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_404',
                         allow_playback_repeats: true, match_requests_on: %i[method body]) do
          can_prefill_vaprofile(true)
          output = form_profile.send(:initialize_military_information).attributes.transform_keys(&:to_s)
          expect(output['currently_active_duty']).to be(false)
          expect(output['currently_active_duty_hash']).to match({ yes: false })
          expect(output['discharge_type']).to be_nil
          expect(output['guard_reserve_service_history']).to eq([])
          expect(output['hca_last_service_branch']).to eq('other')
          expect(output['last_discharge_date']).to be_nil
          expect(output['last_entry_date']).to be_nil
          expect(output['last_service_branch']).to be_nil
          expect(output['latest_guard_reserve_service_period']).to be_nil
          expect(output['post_nov111998_combat']).to be(false)
          expect(output['service_branches']).to eq([])
          expect(output['service_episodes_by_date']).to eq([])
          expect(output['service_periods']).to eq([])
          expect(output['sw_asia_combat']).to be(false)
          expect(output['tours_of_duty']).to eq([])
        end
      end
    end

    context 'when VA Profile returns 500', :skip_va_profile do
      it 'sends a BackendServiceException to Sentry and returns and empty hash' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_500',
                         allow_playback_repeats: true, match_requests_on: %i[method uri]) do
          expect(form_profile).to receive(:log_exception_to_rails)
          expect(form_profile.send(:initialize_va_profile_prefill_military_information)).to eq({})
        end
      end
    end

    context 'with military information data', :skip_va_profile do
      context 'with a user that can prefill VA Profile' do
        before do
          expect(user).to receive(:authorize).at_least(:once).with(:va_profile, :access_to_v2?).and_return(true)
          can_prefill_vaprofile(true)
        end

        context 'with a 686c-674 form v3 enabled' do
          let(:v686_c_674_v2_expected) do
            {
              'veteranContactInformation' => {
                'veteranAddress' => {
                  'street' => '140 Rock Creek Rd',
                  'country' => 'USA',
                  'city' => 'Washington',
                  'state' => 'DC',
                  'postalCode' => '20011'
                },
                'phoneNumber' => us_phone,
                'emailAddress' => user.va_profile_email
              },
              'nonPrefill' => {
                'dependents' => {
                  'success' => 'false'
                },
                'veteranSsnLastFour' => '1863',
                'veteranVaFileNumberLastFour' => '1863',
                'isInReceiptOfPension' => -1,
                'netWorthLimit' => 163_699
              },
              'veteranInformation' => {
                'fullName' => {
                  'first' => user.first_name.capitalize,
                  'last' => user.last_name.capitalize
                },
                'ssn' => '796111863',
                'birthDate' => '1809-02-12'
              }
            }
          end

          before do
            allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, anything).and_return(true)
          end

          it 'omits address fields in 686c-674-V2 form' do
            VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                             allow_playback_repeats: true) do
              expect_prefilled('686C-674-V2')
            end
          end

          context 'with pension awards prefill' do
            let(:user) { create(:evss_user, :loa3) }
            let(:form_profile) do
              FormProfiles::VA686c674v2.new(user:, form_id: '686C-674-V2')
            end

            before do
              allow(Rails.logger).to receive(:warn)
            end

            it 'prefills net worth limit with default value when using get_current_awards' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                # Mock get_current_awards to return IP award line type
                mock_response_body = {
                  'award' => {
                    'award_event_list' => {
                      'award_events' => [
                        {
                          'award_line_list' => {
                            'award_lines' => [
                              {
                                'award_line_type' => 'IP',
                                'effective_date' => '2020-01-01T00:00:00-05:00'
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                }
                allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                  OpenStruct.new(body: mock_response_body)
                )

                prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]
                expect(prefilled_data['nonPrefill']['netWorthLimit']).to eq(163_699)
              end
            end

            it 'prefills 1 when user is in receipt of pension (IP award line type)' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                # Mock get_current_awards to return IP award line type with effective date before today
                mock_response_body = {
                  'award' => {
                    'award_event_list' => {
                      'award_events' => [
                        {
                          'award_line_list' => {
                            'award_lines' => [
                              {
                                'award_line_type' => 'IP',
                                'effective_date' => '2020-01-01T00:00:00-05:00'
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                }
                allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                  OpenStruct.new(body: mock_response_body)
                )

                prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(1)
              end
            end

            it 'prefills 0 when user has non-IP award line type (not receiving pension)' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                # Mock get_current_awards to return non-IP award line type
                mock_response_body = {
                  'award' => {
                    'award_event_list' => {
                      'award_events' => [
                        {
                          'award_line_list' => {
                            'award_lines' => [
                              {
                                'award_line_type' => 'COMP',
                                'effective_date' => '2020-01-01T00:00:00-05:00'
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                }
                allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                  OpenStruct.new(body: mock_response_body)
                )

                prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(0)
              end
            end

            it 'prefills -1 and default net worth limit when bid awards service returns an error' do
              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(dependents_data)

              error = StandardError.new('awards pension error')
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_raise(error)

                monitor = instance_double(DependentsBenefits::Monitor)
                allow(DependentsBenefits::Monitor).to receive(:new).and_return(monitor)
                allow(monitor).to receive(:track_prefill_warning)

                prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                expect(monitor)
                  .to have_received(:track_prefill_warning)
                  .with(
                    'Failed to retrieve awards pension data', 'awards_pension_error',
                    hash_including(
                      user_account_uuid: user&.user_account_uuid,
                      error: error.message,
                      form_id: '686C-674-V2'
                    )
                  )

                expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(-1)
                expect(prefilled_data['nonPrefill']['netWorthLimit']).to eq(163_699)
              end
            end
          end

          context 'with dependents prefill' do
            let(:user) { create(:evss_user, :loa3) }
            let(:form_profile) { FormProfiles::VA686c674v2.new(user:, form_id: '686C-674-V2') }

            before { allow(Rails.logger).to receive(:warn) }

            it 'returns formatted dependent information' do
              # Mock the dependent service to return active dependents
              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(dependents_data)

              result = form_profile.prefill
              expect(result[:form_data]).to have_key('veteranInformation')
              expect(result[:form_data]).to have_key('veteranContactInformation')
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']).to have_key('dependents')
              expect(result[:form_data]['nonPrefill']['dependents']['dependents']).to eq(dependents_information)
            end

            it 'handles a dependent information error' do
              # Mock the dependent service to return an error
              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_raise(
                StandardError.new('Dependent information error')
              )
              result = form_profile.prefill
              expect(result[:form_data]).to have_key('veteranInformation')
              expect(result[:form_data]).to have_key('veteranContactInformation')
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']['dependents']).not_to have_key('dependents')
            end

            it 'handles missing dependents data' do
              # Mock the dependent service to return no dependents
              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(nil)
              result = form_profile.prefill
              expect(result[:form_data]).to have_key('veteranInformation')
              expect(result[:form_data]).to have_key('veteranContactInformation')
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']['dependents']).not_to have_key('dependents')
            end

            it 'handles invalid date formats gracefully' do
              invalid_date_data = dependents_data.dup
              invalid_date_data[:persons][0][:date_of_birth] = 'invalid-date'

              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(invalid_date_data)

              result = form_profile.prefill
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']).to have_key('dependents')
              dependents = result[:form_data]['nonPrefill']['dependents']
              expect(dependents).to be_an(Object)
              expect(dependents['dependents'].first['dateOfBirth']).to be_nil
            end

            it 'handles nil date gracefully' do
              nil_date_data = dependents_data.dup
              nil_date_data[:persons][0][:date_of_birth] = nil

              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(nil_date_data)

              result = form_profile.prefill
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']).to have_key('dependents')
              dependents = result[:form_data]['nonPrefill']['dependents']
              expect(dependents).to be_an(Object)
              expect(dependents['dependents'].first['dateOfBirth']).to be_nil
            end

            it 'handles blank dependents data' do
              # Test line 160: when dependents.blank? or dependents[:persons].blank?, sets @dependents_information to []
              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(nil)

              result = form_profile.prefill
              # When dependents are blank but no error occurs, success is true but no dependents key is created
              expect(result[:form_data]['nonPrefill']['dependents']['success']).to eq('true')
            end
          end
        end

        context 'with a 686c-674 form v3 disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_dependents_v3, anything).and_return(false)
          end

          it 'omits address fields in 686c-674-V2 form' do
            VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                             allow_playback_repeats: true) do
              expect_prefilled('686C-674-V2')
            end
          end

          context 'with pension awards prefill' do
            let(:user) { create(:evss_user, :loa3) }
            let(:form_profile) do
              FormProfiles::VA686c674v2.new(user:, form_id: '686C-674-V2')
            end

            before do
              allow(Rails.logger).to receive(:warn)
            end

            it 'prefills net worth limit with default value when using get_current_awards' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                # Mock get_current_awards to return IP award line type
                mock_response_body = {
                  'award' => {
                    'award_event_list' => {
                      'award_events' => [
                        {
                          'award_line_list' => {
                            'award_lines' => [
                              {
                                'award_line_type' => 'IP',
                                'effective_date' => '2020-01-01T00:00:00-05:00'
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                }
                allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                  OpenStruct.new(body: mock_response_body)
                )

                prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]
                expect(prefilled_data['nonPrefill']['netWorthLimit']).to eq(163_699)
              end
            end

            it 'prefills 1 when user is in receipt of pension (IP award line type)' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                # Mock get_current_awards to return IP award line type with effective date before today
                mock_response_body = {
                  'award' => {
                    'award_event_list' => {
                      'award_events' => [
                        {
                          'award_line_list' => {
                            'award_lines' => [
                              {
                                'award_line_type' => 'IP',
                                'effective_date' => '2020-01-01T00:00:00-05:00'
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                }
                allow_any_instance_of(BID::Awards::Service).to receive(:get_current_awards).and_return(
                  OpenStruct.new(body: mock_response_body)
                )

                prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(1)
              end
            end

            it 'prefills 0 when user is not in receipt of pension' do
              prefill_no_receipt_of_pension = {
                is_in_receipt_of_pension: false
              }
              form_profile_instance = described_class.for(form_id: '686C-674-V2', user:)
              allow(form_profile_instance).to receive(:awards_pension).and_return(prefill_no_receipt_of_pension)
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                prefilled_data = form_profile_instance.prefill[:form_data]

                expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(0)
              end
            end

            it 'prefills -1 and default net worth limit when bid awards service returns an error' do
              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(dependents_data)

              error = StandardError.new('awards pension error')
              VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                               allow_playback_repeats: true) do
                allow_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_raise(error)

                expect(Rails.logger).to receive(:warn).with('Failed to retrieve awards pension data', anything)

                prefilled_data = described_class.for(form_id: '686C-674-V2', user:).prefill[:form_data]

                expect(prefilled_data['nonPrefill']['isInReceiptOfPension']).to eq(-1)
                expect(prefilled_data['nonPrefill']['netWorthLimit']).to eq(163_699)
              end
            end
          end

          context 'with dependents prefill' do
            let(:user) { create(:evss_user, :loa3) }
            let(:form_profile) { FormProfiles::VA686c674v2.new(user:, form_id: '686C-674-V2') }

            before { allow(Rails.logger).to receive(:warn) }

            it 'returns formatted dependent information' do
              # Mock the dependent service to return active dependents
              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(dependents_data)

              result = form_profile.prefill
              expect(result[:form_data]).to have_key('veteranInformation')
              expect(result[:form_data]).to have_key('veteranContactInformation')
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']).to have_key('dependents')
              expect(result[:form_data]['nonPrefill']['dependents']).to eq(dependents_information)
            end

            it 'handles a dependent information error' do
              # Mock the dependent service to return an error
              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_raise(
                StandardError.new('Dependent information error')
              )
              result = form_profile.prefill
              expect(result[:form_data]).to have_key('veteranInformation')
              expect(result[:form_data]).to have_key('veteranContactInformation')
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']).not_to have_key('dependents')
            end

            it 'handles missing dependents data' do
              # Mock the dependent service to return no dependents
              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(nil)
              result = form_profile.prefill
              expect(result[:form_data]).to have_key('veteranInformation')
              expect(result[:form_data]).to have_key('veteranContactInformation')
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']).not_to have_key('dependents')
            end

            it 'handles invalid date formats gracefully' do
              invalid_date_data = dependents_data.dup
              invalid_date_data[:persons][0][:date_of_birth] = 'invalid-date'

              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(invalid_date_data)

              result = form_profile.prefill
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']).to have_key('dependents')
              dependents = result[:form_data]['nonPrefill']['dependents']
              expect(dependents).to be_an(Array)
              expect(dependents.first['dateOfBirth']).to be_nil
            end

            it 'handles nil date gracefully' do
              nil_date_data = dependents_data.dup
              nil_date_data[:persons][0][:date_of_birth] = nil

              allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
              allow(dependent_service).to receive(:get_dependents).and_return(nil_date_data)

              result = form_profile.prefill
              expect(result[:form_data]).to have_key('nonPrefill')
              expect(result[:form_data]['nonPrefill']).to have_key('dependents')
              dependents = result[:form_data]['nonPrefill']['dependents']
              expect(dependents).to be_an(Array)
              expect(dependents.first['dateOfBirth']).to be_nil
            end
          end

          it 'returns prefilled 686C-674-V2' do
            VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                             allow_playback_repeats: true, match_requests_on: %i[uri method body]) do
              expect_prefilled('686C-674-V2')
            end
          end
        end
      end
    end
  end

  describe 'Additional Specs' do
    let(:va686c674_form_profile) { DependentsBenefits::FormProfiles::VA686c674.new(form_id: '686C-674', user:) }

    describe '#prefill_form_address' do
      it 'handles VA Profile error gracefully' do
        allow(VAProfileRedis::V2::ContactInformation)
          .to receive(:for_user)
          .with(user)
          .and_raise(StandardError.new('VA Profile error'))

        expect { va686c674_form_profile.send(:prefill_form_address) }.not_to raise_error
        expect(va686c674_form_profile.instance_variable_get(:@form_address)).to be_nil
      end
    end

    describe '#va_file_number' do
      it 'handles BGS error and calls monitor with fallback to SSN' do
        allow(BGS::People::Request).to receive(:new).and_raise(StandardError.new('BGS error'))
        monitor_instance = instance_double(DependentsBenefits::Monitor)
        allow(va686c674_form_profile).to receive(:monitor).and_return(monitor_instance)

        expect(monitor_instance).to receive(:track_prefill_warning).with(
          'Failed to retrieve VA file number',
          'file_number_error',
          hash_including(error: 'BGS error')
        )

        result = va686c674_form_profile.send(:va_file_number)
        expect(result).to eq(user.ssn.presence)
      end
    end

    describe '#prefill_dependents_information' do
      it 'sets empty array when dependents is blank' do
        dependent_service = instance_double(BGS::DependentService)
        allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
        allow(dependent_service).to receive(:get_dependents).and_return(nil)

        va686c674_form_profile.send(:prefill_dependents_information)

        # When v3 is enabled, it should be a hash, when disabled it should be an array
        result = va686c674_form_profile.instance_variable_get(:@dependents_information)
        expect(result[:dependents]).to eq([])
      end
    end

    describe '#parse_date_safely' do
      it 'handles ArgumentError by returning nil' do
        result = va686c674_form_profile.send(:parse_date_safely, 'invalid/date/format')
        expect(result).to be_nil
      end

      it 'handles TypeError by returning nil' do
        allow(Date).to receive(:strptime).and_raise(TypeError.new('Type error'))

        result = va686c674_form_profile.send(:parse_date_safely, 'some-date')
        expect(result).to be_nil
      end
    end
  end
end
