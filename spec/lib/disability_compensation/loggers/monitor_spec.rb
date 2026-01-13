# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/loggers/monitor'

RSpec.describe DisabilityCompensation::Loggers::Monitor do
  let(:monitor) { described_class.new }

  # Simple test to ensure monitor successfully implements abstract methods in lib/logging/base_monitor.rb
  describe('#submit_event') do
    it 'logs with the appropriate Disability Compensation key prefixes and metadata' do
      payload = {
        confirmation_number: nil,
        user_account_uuid: '1234',
        claim_id: '1234',
        form_id: described_class::FORM_ID,
        tags: ['form_id:21-526EZ-ALLCLAIMS'],
        additional_context_key: 'value'
      }

      expect(monitor).to receive(:track_request).with(
        :error,
        'Example message',
        described_class::CLAIM_STATS_KEY,
        call_location: anything,
        **payload
      )

      monitor.send(
        :submit_event,
        :error,
        'Example message',
        described_class::CLAIM_STATS_KEY,
        **payload
      )
    end
  end

  describe('#track_saved_claim_save_error') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }
    let(:in_progress_form) { create(:in_progress_form) }
    let(:mock_form_error) { 'Mock form validation error' }

    let(:claim_with_save_error) do
      claim = SavedClaim::DisabilityCompensation::Form526AllClaim.new
      errors = ActiveModel::Errors.new(claim)
      errors.add(:form, mock_form_error)
      allow(claim).to receive_messages(errors:)
      claim
    end

    it 'logs the error metadata' do
      expect(monitor).to receive(:submit_event).with(
        :error,
        "#{described_class} Form526 SavedClaim save error",
        "#{described_class::CLAIM_STATS_KEY}.failure",
        form_id: described_class::FORM_ID,
        in_progress_form_id: in_progress_form.id,
        errors: [{ form: mock_form_error }].to_s,
        user_account_uuid: user.uuid
      )

      monitor.track_saved_claim_save_error(
        claim_with_save_error.errors.errors,
        in_progress_form.id,
        user.uuid
      )
    end

    # NOTE: in_progress_form_id, user_account_uuid, and errors keys are whitelisted payload keys
    # for monitors inheriting from Logging::BaseMonitor; ensures this information will not be filtered out when it is
    # written to the Rails logger; see config/initializers/filter_parameter_logging.rb
    it 'does not filter out error details when writing to the Rails logger' do
      expect(Rails.logger).to receive(:error) do |_, payload|
        expect(payload[:context][:user_account_uuid]).to eq(user.uuid)
        expect(payload[:context][:errors]).to eq([{ form: mock_form_error }].to_s)
        expect(payload[:context][:in_progress_form_id]).to eq(in_progress_form.id)
      end

      monitor.track_saved_claim_save_error(
        claim_with_save_error.errors,
        in_progress_form.id,
        user.uuid
      )
    end
  end

  describe('#track_saved_claim_save_success') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }
    let(:claim) { build(:fake_saved_claim, form_id: described_class::FORM_ID, guid: '1234') }

    it 'logs the success' do
      expect(monitor).to receive(:submit_event).with(
        :info,
        "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}",
        "#{described_class::CLAIM_STATS_KEY}.success",
        claim:,
        user_account_uuid: user.uuid,
        form_id: described_class::FORM_ID
      )

      monitor.track_saved_claim_save_success(
        claim,
        user.uuid
      )
    end
  end

  describe('#track_toxic_exposure_changes') do
    # InProgressForm uses snake_case (Rails auto-transforms save-in-progress forms)
    let(:in_progress_form_data) do
      {
        'toxic_exposure' => {
          'conditions' => { 'asthma' => true },
          'gulf_war_1990' => { 'iraq' => true }
        }
      }
    end
    let(:in_progress_form) { create(:in_progress_form, form_id: '21-526EZ', form_data: in_progress_form_data.to_json) }
    let(:submitted_claim) { build(:fake_saved_claim, form_id: described_class::FORM_ID, guid: '1234') }
    let(:submission) { instance_double(Form526Submission, id: 67_890) }

    shared_examples 'logs changes event' do |removed_keys:, completely_removed:, orphaned_data_removed: false|
      it 'logs with correct keys' do
        expect(monitor).to receive(:submit_event).with(
          :info,
          'Form526Submission toxic exposure data purged',
          "#{described_class::CLAIM_STATS_KEY}.toxic_exposure_changes",
          hash_including(
            submission_id: submission.id,
            removed_keys:,
            completely_removed:,
            orphaned_data_removed:,
            purge_reasons: kind_of(Hash),
            conditions_state: kind_of(String)
          )
        )
        monitor.track_toxic_exposure_changes(in_progress_form:, submitted_claim:, submission:)
      end
    end

    context 'when key removed' do
      before do
        # SavedClaim uses camelCase
        form_data = {
          'toxicExposure' => {
            'conditions' => { 'asthma' => true }
          }
        }
        allow(submitted_claim).to receive(:form).and_return(form_data.to_json)
      end

      include_examples 'logs changes event', removed_keys: ['gulfWar1990'], completely_removed: false
    end

    context 'when conditions key removed' do
      before do
        # SavedClaim uses camelCase
        form_data = {
          'toxicExposure' => {
            'gulfWar1990' => { 'iraq' => true }
          }
        }
        allow(submitted_claim).to receive(:form).and_return(form_data.to_json)
      end

      include_examples 'logs changes event', removed_keys: ['conditions'], completely_removed: false
    end

    context 'when all keys removed but toxicExposure object exists (empty hash)' do
      before do
        # SavedClaim uses camelCase
        form_data = {
          'toxicExposure' => {}
        }
        allow(submitted_claim).to receive(:form).and_return(form_data.to_json)
      end

      # Tests that empty hash is treated differently from nil (completely_removed: false vs true)
      include_examples 'logs changes event', removed_keys: %w[conditions gulfWar1990], completely_removed: false
    end

    context 'when multiple keys removed (2 keys)' do
      before do
        # InProgressForm uses snake_case
        in_progress_data = {
          'toxic_exposure' => {
            'conditions' => { 'asthma' => true },
            'gulf_war_1990' => { 'iraq' => true },
            'gulf_war_2001' => { 'afghanistan' => true }
          }
        }
        allow(in_progress_form).to receive(:form_data).and_return(in_progress_data.to_json)

        # SavedClaim uses camelCase (2 keys removed)
        form_data = {
          'toxicExposure' => {
            'conditions' => { 'asthma' => true }
          }
        }
        allow(submitted_claim).to receive(:form).and_return(form_data.to_json)
      end

      include_examples 'logs changes event', removed_keys: %w[gulfWar1990 gulfWar2001], completely_removed: false
    end

    context 'when completely removed' do
      before { allow(submitted_claim).to receive(:form).and_return({}.to_json) }

      include_examples 'logs changes event', removed_keys: %w[conditions gulfWar1990], completely_removed: true
    end

    context 'when unchanged' do
      before do
        # SavedClaim uses camelCase - same data as InProgressForm but in camelCase
        saved_claim_data = {
          'toxicExposure' => {
            'conditions' => { 'asthma' => true },
            'gulfWar1990' => { 'iraq' => true }
          }
        }
        allow(submitted_claim).to receive(:form).and_return(saved_claim_data.to_json)
      end

      it 'does not log when data matches (despite format difference)' do
        expect(monitor).not_to receive(:submit_event)
        monitor.track_toxic_exposure_changes(in_progress_form:, submitted_claim:, submission:)
      end
    end

    # False positive prevention tests - ensure no logging when no actual data purged
    context 'when user opts out but never entered actual data (false positive prevention)' do
      context 'with empty form scaffolding (none: true, empty objects)' do
        let(:in_progress_form_data) do
          {
            'toxic_exposure' => {
              'conditions' => { 'none' => true },
              'gulf_war_1990' => {},
              'gulf_war_2001' => {},
              'herbicide' => {},
              'other_exposures' => {}
            }
          }
        end

        before do
          allow(in_progress_form).to receive(:form_data).and_return(in_progress_form_data.to_json)
          # Frontend returns unchanged - same empty scaffolding (no actual purge)
          saved_claim_data = {
            'toxicExposure' => {
              'conditions' => { 'none' => true },
              'gulfWar1990' => {},
              'gulfWar2001' => {},
              'herbicide' => {},
              'otherExposures' => {}
            }
          }
          allow(submitted_claim).to receive(:form).and_return(saved_claim_data.to_json)
        end

        it 'does not log when frontend returns unchanged empty scaffolding' do
          expect(monitor).not_to receive(:submit_event)
          monitor.track_toxic_exposure_changes(in_progress_form:, submitted_claim:, submission:)
        end
      end

      context 'with all false values (no actual selections)' do
        let(:in_progress_form_data) do
          {
            'toxic_exposure' => {
              'conditions' => { 'asthma' => false, 'cancer' => false, 'none' => false },
              'gulf_war_1990' => { 'iraq' => false, 'bahrain' => false },
              'herbicide' => { 'vietnam' => false, 'cambodia' => false }
            }
          }
        end

        before do
          allow(in_progress_form).to receive(:form_data).and_return(in_progress_form_data.to_json)
          # Frontend returns unchanged - same false values (no actual purge)
          saved_claim_data = {
            'toxicExposure' => {
              'conditions' => { 'asthma' => false, 'cancer' => false, 'none' => false },
              'gulfWar1990' => { 'iraq' => false, 'bahrain' => false },
              'herbicide' => { 'vietnam' => false, 'cambodia' => false }
            }
          }
          allow(submitted_claim).to receive(:form).and_return(saved_claim_data.to_json)
        end

        it 'does not log when frontend returns unchanged false values' do
          expect(monitor).not_to receive(:submit_event)
          monitor.track_toxic_exposure_changes(in_progress_form:, submitted_claim:, submission:)
        end
      end

      context 'with nested empty objects in details' do
        let(:in_progress_form_data) do
          {
            'toxic_exposure' => {
              'conditions' => {},
              'gulf_war_1990' => {},
              'gulf_war_1990_details' => {
                'afghanistan' => {},
                'bahrain' => {},
                'iraq' => {}
              },
              'herbicide' => {},
              'herbicide_details' => {
                'vietnam' => {},
                'cambodia' => {}
              }
            }
          }
        end

        before do
          allow(in_progress_form).to receive(:form_data).and_return(in_progress_form_data.to_json)
          # Frontend returns unchanged - same empty nested objects
          saved_claim_data = {
            'toxicExposure' => {
              'conditions' => {},
              'gulfWar1990' => {},
              'gulfWar1990Details' => {
                'afghanistan' => {},
                'bahrain' => {},
                'iraq' => {}
              },
              'herbicide' => {},
              'herbicideDetails' => {
                'vietnam' => {},
                'cambodia' => {}
              }
            }
          }
          allow(submitted_claim).to receive(:form).and_return(saved_claim_data.to_json)
        end

        it 'does not log when frontend returns unchanged nested empty objects' do
          expect(monitor).not_to receive(:submit_event)
          monitor.track_toxic_exposure_changes(in_progress_form:, submitted_claim:, submission:)
        end
      end

      # Test case for: condition selected but no exposure data entered
      # otherHerbicideLocations: {} and specifyOtherExposures: {} are stripped by frontend
      context 'with condition selected but empty other fields stripped (real-world scenario)' do
        let(:in_progress_form_data) do
          {
            'toxic_exposure' => {
              'conditions' => { 'asthma' => true },
              'gulf_war_1990' => {},
              'gulf_war_1990_details' => { 'afghanistan' => {}, 'iraq' => {} },
              'herbicide' => {},
              'herbicide_details' => { 'vietnam' => {}, 'cambodia' => {} },
              'other_herbicide_locations' => {},
              'other_exposures' => {},
              'other_exposures_details' => { 'asbestos' => {}, 'radiation' => {} },
              'specify_other_exposures' => {}
            }
          }
        end

        before do
          allow(in_progress_form).to receive(:form_data).and_return(in_progress_form_data.to_json)
          # Frontend strips empty otherKey fields - they're missing in submitted data
          saved_claim_data = {
            'toxicExposure' => {
              'conditions' => { 'asthma' => true },
              'gulfWar1990' => {},
              'gulfWar1990Details' => {},
              'herbicide' => {},
              'herbicideDetails' => {},
              'otherExposures' => {},
              'otherExposuresDetails' => {}
              # NOTE: otherHerbicideLocations and specifyOtherExposures are MISSING
              # because frontend purge removes empty otherKey objects
            }
          }
          allow(submitted_claim).to receive(:form).and_return(saved_claim_data.to_json)
        end

        it 'does not log when empty other fields are stripped (no actual data purged)' do
          expect(monitor).not_to receive(:submit_event)
          monitor.track_toxic_exposure_changes(in_progress_form:, submitted_claim:, submission:)
        end
      end
    end

    # True positive tests - ensure logging DOES happen when actual data is purged
    context 'when user opts out AND had actual data (true positive - should log)' do
      context 'with actual condition selections purged' do
        let(:in_progress_form_data) do
          {
            'toxic_exposure' => {
              'conditions' => { 'asthma' => true, 'cancer' => true },
              'gulf_war_1990' => { 'iraq' => true },
              'gulf_war_1990_details' => {
                'iraq' => { 'start_date' => '1991-01-01', 'end_date' => '1991-12-31' }
              }
            }
          }
        end

        before do
          allow(in_progress_form).to receive(:form_data).and_return(in_progress_form_data.to_json)
          # Frontend purged data - only conditions remain with none: true
          saved_claim_data = {
            'toxicExposure' => {
              'conditions' => { 'none' => true }
            }
          }
          allow(submitted_claim).to receive(:form).and_return(saved_claim_data.to_json)
        end

        include_examples 'logs changes event',
                         removed_keys: %w[gulfWar1990 gulfWar1990Details],
                         completely_removed: false
      end

      context 'with partial data purged (unchecked checkbox removes details)' do
        let(:in_progress_form_data) do
          {
            'toxic_exposure' => {
              'conditions' => { 'asthma' => true },
              'gulf_war_1990' => { 'iraq' => true, 'bahrain' => true },
              'gulf_war_1990_details' => {
                'iraq' => { 'start_date' => '1991-01-01' },
                'bahrain' => { 'start_date' => '1990-08-01' }
              },
              'herbicide' => { 'vietnam' => true },
              'herbicide_details' => {
                'vietnam' => { 'start_date' => '1968-01-01' }
              }
            }
          }
        end

        before do
          allow(in_progress_form).to receive(:form_data).and_return(in_progress_form_data.to_json)
          # Frontend filtered details for false checkboxes, removed herbicide section
          saved_claim_data = {
            'toxicExposure' => {
              'conditions' => { 'asthma' => true },
              'gulfWar1990' => { 'iraq' => true, 'bahrain' => false },
              'gulfWar1990Details' => {
                'iraq' => { 'startDate' => '1991-01-01' }
              }
            }
          }
          allow(submitted_claim).to receive(:form).and_return(saved_claim_data.to_json)
        end

        # herbicideDetails is correctly classified as orphaned since herbicide parent is removed
        include_examples 'logs changes event',
                         removed_keys: %w[herbicide herbicideDetails],
                         completely_removed: false,
                         orphaned_data_removed: true
      end
    end

    context 'when verifying allowlist filtering' do
      before do
        # SavedClaim uses camelCase
        form_data = {
          'toxicExposure' => {
            'conditions' => { 'asthma' => true }
          }
        }
        allow(submitted_claim).to receive(:form).and_return(form_data.to_json)
      end

      # NOTE: submission_id, completely_removed, removed_keys, purge_reasons, conditions_state,
      # orphaned_data_removed, and tags are allowlisted in DisabilityCompensation::Loggers::Monitor#initialize
      # to ensure they are not filtered when written to Rails.logger. This test verifies the allowlist is
      # working correctly.
      it 'does not filter out allowlisted toxic exposure tracking keys when writing to Rails logger' do
        expect(Rails.logger).to receive(:info) do |_, payload|
          expect(payload[:context][:submission_id]).to eq(submission.id)
          expect(payload[:context][:completely_removed]).to be(false)
          expect(payload[:context][:removed_keys]).to eq(['gulfWar1990'])
          expect(payload[:context][:purge_reasons]).to be_a(Hash)
          expect(payload[:context][:conditions_state]).to be_a(String)
          expect(payload[:context][:orphaned_data_removed]).to be_in([true, false])
          expect(payload[:context][:tags]).to eq(['form_id:21-526EZ-ALLCLAIMS'])
        end

        monitor.track_toxic_exposure_changes(in_progress_form:, submitted_claim:, submission:)
      end
    end
  end

  describe('#analyze_purge_reasons (private)') do
    # Reuse monitor from outer scope (line 7)
    # Test the private method directly using send
    def analyze_purge_reasons(removed_keys, in_progress_data, submitted_toxic_exposure)
      monitor.send(:analyze_purge_reasons, removed_keys, in_progress_data, submitted_toxic_exposure)
    end

    context 'when submitted_toxic_exposure is nil (complete removal)' do
      it 'returns user_opted_out_of_conditions for all keys' do
        result = analyze_purge_reasons(%w[conditions gulfWar1990], {}, nil)

        expect(result[:purge_reasons]).to eq({ all: 'user_opted_out_of_conditions' })
        expect(result[:orphaned_data_removed]).to be(false)
      end
    end

    context 'when user selected none for conditions' do
      it 'categorizes all removed keys as user_selected_none_for_conditions' do
        result = analyze_purge_reasons(
          %w[gulfWar1990 gulfWar1990Details herbicide],
          { 'gulfWar1990' => { 'iraq' => true }, 'gulfWar1990Details' => {}, 'herbicide' => {} },
          { 'conditions' => { 'none' => true } }
        )

        expect(result[:purge_reasons].values.uniq).to eq(['user_selected_none_for_conditions'])
        expect(result[:orphaned_data_removed]).to be(false)
      end
    end

    # Consolidated: Tests orphaned details for various invalid parent states
    context 'when details are orphaned (parent missing, nil, or invalid type)' do
      [
        { parent_state: 'missing', submitted: { 'conditions' => { 'asthma' => true } } },
        { parent_state: 'nil', submitted: { 'conditions' => { 'asthma' => true }, 'gulfWar1990' => nil } },
        { parent_state: 'invalid type', submitted: { 'conditions' => { 'asthma' => true }, 'gulfWar1990' => 'string' } }
      ].each do |scenario|
        it "categorizes as orphaned_details_no_parent when parent is #{scenario[:parent_state]}" do
          result = analyze_purge_reasons(['gulfWar1990Details'], {}, scenario[:submitted])

          expect(result[:purge_reasons]['gulfWar1990Details']).to eq('orphaned_details_no_parent')
          expect(result[:orphaned_data_removed]).to be(true)
        end
      end
    end

    # Consolidated: Tests user deselected locations for various valid parent states
    context 'when user deselected all locations (parent exists as valid hash)' do
      [
        { parent_state: 'empty hash', parent_value: {} },
        { parent_state: 'false values', parent_value: { 'iraq' => false } }
      ].each do |scenario|
        it "categorizes as user_deselected_all_locations when parent is #{scenario[:parent_state]}" do
          submitted = { 'conditions' => { 'asthma' => true }, 'gulfWar1990' => scenario[:parent_value] }
          result = analyze_purge_reasons(['gulfWar1990Details'], {}, submitted)

          expect(result[:purge_reasons]['gulfWar1990Details']).to eq('user_deselected_all_locations')
          expect(result[:orphaned_data_removed]).to be(false)
        end
      end
    end

    # Consolidated: Tests orphaned other fields for both field types
    context 'when other fields are orphaned (parent missing or nil)' do
      [
        { field: 'otherHerbicideLocations', parent: 'herbicide', submitted: { 'conditions' => { 'asthma' => true } } },
        { field: 'specifyOtherExposures', parent: 'otherExposures',
          submitted: { 'conditions' => { 'asthma' => true }, 'otherExposures' => nil } }
      ].each do |scenario|
        it "categorizes #{scenario[:field]} as orphaned_other_field_no_parent" do
          result = analyze_purge_reasons([scenario[:field]], {}, scenario[:submitted])

          expect(result[:purge_reasons][scenario[:field]]).to eq('orphaned_other_field_no_parent')
          expect(result[:orphaned_data_removed]).to be(true)
        end
      end
    end

    context 'when user opted out of other field (parent exists)' do
      it 'categorizes as user_opted_out_of_other_field' do
        result = analyze_purge_reasons(
          ['otherHerbicideLocations'],
          {},
          { 'conditions' => { 'asthma' => true }, 'herbicide' => { 'vietnam' => true } }
        )

        expect(result[:purge_reasons]['otherHerbicideLocations']).to eq('user_opted_out_of_other_field')
        expect(result[:orphaned_data_removed]).to be(false)
      end
    end

    context 'when section is deselected (gulfWar1990, herbicide, etc.)' do
      let(:submitted_data) { { 'conditions' => { 'asthma' => true } } }

      it 'categorizes as user_deselected_section' do
        result = analyze_purge_reasons(
          %w[gulfWar1990 herbicide otherExposures],
          { 'gulfWar1990' => {}, 'herbicide' => {}, 'otherExposures' => {} },
          submitted_data
        )

        expect(result[:purge_reasons]['gulfWar1990']).to eq('user_deselected_section')
        expect(result[:purge_reasons]['herbicide']).to eq('user_deselected_section')
        expect(result[:purge_reasons]['otherExposures']).to eq('user_deselected_section')
        expect(result[:orphaned_data_removed]).to be(false)
      end
    end

    context 'when conditions key is removed' do
      let(:submitted_data) { { 'gulfWar1990' => { 'iraq' => true } } }

      it 'categorizes as user_deselected_section' do
        result = analyze_purge_reasons(
          ['conditions'],
          { 'conditions' => { 'asthma' => true } },
          submitted_data
        )

        expect(result[:purge_reasons]['conditions']).to eq('user_deselected_section')
        expect(result[:orphaned_data_removed]).to be(false)
      end
    end

    context 'with mixed removal reasons' do
      let(:submitted_data) do
        {
          'conditions' => { 'asthma' => true },
          'gulfWar1990' => { 'iraq' => false }
        }
      end

      it 'correctly categorizes each removed key' do
        result = analyze_purge_reasons(
          %w[gulfWar1990Details gulfWar2001Details herbicide],
          {
            'gulfWar1990Details' => {},
            'gulfWar2001Details' => {},
            'herbicide' => {}
          },
          submitted_data
        )

        # gulfWar1990 exists (as hash with false) - user deselected
        expect(result[:purge_reasons]['gulfWar1990Details']).to eq('user_deselected_all_locations')
        # gulfWar2001 doesn't exist - orphaned
        expect(result[:purge_reasons]['gulfWar2001Details']).to eq('orphaned_details_no_parent')
        # herbicide is a section key
        expect(result[:purge_reasons]['herbicide']).to eq('user_deselected_section')
        expect(result[:orphaned_data_removed]).to be(true)
      end
    end
  end

  describe('#determine_conditions_state (private)') do
    # Reuse monitor from outer scope (line 7)
    def determine_conditions_state(submitted_toxic_exposure)
      monitor.send(:determine_conditions_state, submitted_toxic_exposure)
    end

    context 'when submitted_toxic_exposure is nil' do
      it 'returns "removed"' do
        expect(determine_conditions_state(nil)).to eq('removed')
      end
    end

    # Consolidated: All scenarios that return "empty"
    context 'when conditions result in "empty" state' do
      [
        { desc: 'conditions key missing', input: {} },
        { desc: 'conditions key missing with other data', input: { 'gulfWar1990' => {} } },
        { desc: 'conditions is empty hash', input: { 'conditions' => {} } },
        { desc: 'conditions has only false values', input: { 'conditions' => { 'asthma' => false } } },
        { desc: 'conditions has none: false with no other selections', input: { 'conditions' => { 'none' => false } } }
      ].each do |scenario|
        it "returns \"empty\" when #{scenario[:desc]}" do
          expect(determine_conditions_state(scenario[:input])).to eq('empty')
        end
      end
    end

    # Consolidated: All scenarios that return "none"
    context 'when user selected none for conditions' do
      [
        { desc: 'none is true', input: { 'conditions' => { 'none' => true } } },
        { desc: 'none is true with other false values',
          input: { 'conditions' => { 'none' => true, 'asthma' => false } } }
      ].each do |scenario|
        it "returns \"none\" when #{scenario[:desc]}" do
          expect(determine_conditions_state(scenario[:input])).to eq('none')
        end
      end
    end

    # Consolidated: All scenarios that return "has_selections"
    context 'when conditions has selections' do
      [
        { desc: 'single true value', input: { 'conditions' => { 'asthma' => true } } },
        { desc: 'multiple true values', input: { 'conditions' => { 'asthma' => true, 'cancer' => true } } },
        { desc: 'true with false values', input: { 'conditions' => { 'asthma' => true, 'cancer' => false } } },
        { desc: 'none: false with other true values', input: { 'conditions' => { 'none' => false, 'asthma' => true } } }
      ].each do |scenario|
        it "returns \"has_selections\" when #{scenario[:desc]}" do
          expect(determine_conditions_state(scenario[:input])).to eq('has_selections')
        end
      end
    end
  end

  describe('#track_526_submission_with_banking_info') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }

    it 'logs the submission' do
      expect(monitor).to receive(:submit_event).with(
        :info,
        'Form 526 submitted with Veteran-supplied banking info',
        "#{described_class::SUBMISSION_STATS_KEY}.with_banking_info",
        user_account_uuid: user.uuid,
        form_id: described_class::FORM_ID
      )

      monitor.track_526_submission_with_banking_info(user.uuid)
    end

    it 'increments the correct metric' do
      expect(StatsD).to receive(:increment).with(
        "#{described_class::SUBMISSION_STATS_KEY}.with_banking_info",
        tags: [
          'service:disability-compensation',
          'function:track_526_submission_with_banking_info',
          "form_id:#{described_class::FORM_ID}"
        ]
      )

      monitor.track_526_submission_with_banking_info(user.uuid)
    end
  end

  describe('#track_526_submission_without_banking_info') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }

    it 'logs the submission and increments the correct metric' do
      expect(monitor).to receive(:submit_event).with(
        :info,
        'Form 526 submitted without Veteran-supplied banking info',
        "#{described_class::SUBMISSION_STATS_KEY}.without_banking_info",
        user_account_uuid: user.uuid,
        form_id: described_class::FORM_ID
      )

      monitor.track_526_submission_without_banking_info(user.uuid)
    end

    it 'increments the correct metric' do
      expect(StatsD).to receive(:increment).with(
        "#{described_class::SUBMISSION_STATS_KEY}.without_banking_info",
        tags: [
          'service:disability-compensation',
          'function:track_526_submission_without_banking_info',
          "form_id:#{described_class::FORM_ID}"
        ]
      )
      monitor.track_526_submission_without_banking_info(user.uuid)
    end
  end

  describe('#track_banking_info_prefilled') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }

    it 'logs the prefill success' do
      expect(monitor).to receive(:submit_event).with(
        :info,
        'Banking info successfully prefilled from Lighthouse Direct Deposit API',
        "#{described_class::SUBMISSION_STATS_KEY}.banking_info_prefilled",
        user_account_uuid: user.uuid,
        form_id: described_class::FORM_ID
      )

      monitor.track_banking_info_prefilled(user.uuid)
    end

    it 'increments the correct metric' do
      expect(StatsD).to receive(:increment).with(
        "#{described_class::SUBMISSION_STATS_KEY}.banking_info_prefilled",
        tags: [
          'service:disability-compensation',
          'function:track_banking_info_prefilled',
          "form_id:#{described_class::FORM_ID}"
        ]
      )

      monitor.track_banking_info_prefilled(user.uuid)
    end
  end

  describe('#track_no_banking_info_on_file') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }

    it 'logs when no banking info is found' do
      expect(monitor).to receive(:submit_event).with(
        :info,
        'No banking info on file for veteran during prefill attempt',
        "#{described_class::SUBMISSION_STATS_KEY}.no_banking_info_on_file",
        user_account_uuid: user.uuid,
        form_id: described_class::FORM_ID
      )

      monitor.track_no_banking_info_on_file(user.uuid)
    end

    it 'increments the correct metric' do
      expect(StatsD).to receive(:increment).with(
        "#{described_class::SUBMISSION_STATS_KEY}.no_banking_info_on_file",
        tags: [
          'service:disability-compensation',
          'function:track_no_banking_info_on_file',
          "form_id:#{described_class::FORM_ID}"
        ]
      )

      monitor.track_no_banking_info_on_file(user.uuid)
    end
  end

  describe('#track_banking_info_api_error') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }
    let(:error) { StandardError.new('Connection timeout to Lighthouse Direct Deposit API') }

    it 'logs the API error' do
      expect(monitor).to receive(:submit_event).with(
        :error,
        'Error retrieving banking info from Lighthouse Direct Deposit API',
        "#{described_class::SUBMISSION_STATS_KEY}.banking_info_api_error",
        user_account_uuid: user.uuid,
        form_id: described_class::FORM_ID,
        error: 'StandardError'
      )

      monitor.track_banking_info_api_error(user.uuid, error)
    end

    it 'increments the correct metric' do
      expect(StatsD).to receive(:increment).with(
        "#{described_class::SUBMISSION_STATS_KEY}.banking_info_api_error",
        tags: [
          'service:disability-compensation',
          'function:track_banking_info_api_error',
          "form_id:#{described_class::FORM_ID}"
        ]
      )

      monitor.track_banking_info_api_error(user.uuid, error)
    end
  end
end
