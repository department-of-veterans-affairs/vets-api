# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'
require 'support/shared_examples_for_mhv'

# rubocop:disable Layout/LineLength
RSpec.describe 'MyHealth::V1::Prescriptions', type: :request do
  include Rx::ClientHelpers
  include SchemaMatchers

  let(:va_patient) { true }
  let(:current_user) do
    build(:user, :mhv, authn_context: LOA::IDME_LOA3_VETS,
                       va_patient:,
                       sign_in: { service_name: SignIn::Constants::Auth::IDME })
  end
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: va_patient))
    allow_any_instance_of(User).to receive(:mhv_correlation_id).and_return('12345678901')
    allow(Rx::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  context 'when user is unauthorized' do
    let(:user) do
      build(:user, :mhv, :no_vha_facilities, authn_context: LOA::IDME_LOA3_VETS, va_patient: false,
                                             sign_in: { service_name: SignIn::Constants::Auth::IDME })
    end

    before { get '/my_health/v1/prescriptions/13651310' }

    include_examples 'for user account level', message: 'You do not have access to prescriptions'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to prescriptions'
  end

  def skip_pending_meds(array)
    array.reject { |item| item['attributes']['prescription_source'] == 'PD' }
  end

  context 'when user is authorized' do
    context 'not a va patient' do
      before { get '/my_health/v1/prescriptions/13651310' }

      let(:va_patient) { false }
      let(:current_user) do
        build(:user,
              :mhv,
              :no_vha_facilities,
              authn_context: LOA::IDME_LOA3_VETS,
              va_patient:,
              sign_in: { service_name: SignIn::Constants::Auth::IDME })
      end

      include_examples 'for non va patient user', authorized: false, message: 'You do not have access to prescriptions'
    end

    it 'responds to GET #show' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_single_grouped_prescription') do
        get '/my_health/v1/prescriptions/24891624'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescription_single')
    end

    it 'responds to GET #show with camel-inlfection' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_single_grouped_prescription') do
        get '/my_health/v1/prescriptions/24891624', headers: inflection_header
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('my_health/prescriptions/v1/prescription_single')
    end

    it 'responds to GET #index with no parameters' do
      allow(UniqueUserEvents).to receive(:log_event)

      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
        get '/my_health/v1/prescriptions'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list')
      expect(JSON.parse(response.body)['meta']['sort']).to eq(
        'disp_status' => 'ASC',
        'prescription_name' => 'ASC',
        'dispensed_date' => 'DESC'
      )

      recently_requested = JSON.parse(response.body)['meta']['recently_requested']
      expect(recently_requested).to be_an(Array)
      recently_requested.each do |prescription|
        expect(prescription['disp_status']).to(satisfy { |status| ['Active: Refill in Process', 'Active: Submitted'].include?(status) })
      end

      # Verify event logging was called
      expect(UniqueUserEvents).to have_received(:log_event).with(
        user: anything,
        event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
      )
    end

    it 'responds to GET #index with no parameters when camel-inflected' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
        get '/my_health/v1/prescriptions', headers: inflection_header
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('my_health/prescriptions/v1/prescriptions_list')
      expect(JSON.parse(response.body)['meta']['sort']).to eq(
        'dispStatus' => 'ASC',
        'prescriptionName' => 'ASC',
        'dispensedDate' => 'DESC'
      )
    end

    it 'responds to GET #index with images' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_with_images_v1') do
        get '/my_health/v1/prescriptions?&sort[]=prescription_name&sort[]=dispensed_date&include_image=true'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list')
      item_index = JSON.parse(response.body)['data'].find_index { |item| item['attributes']['prescription_image'] }
      expect(item_index).not_to be_nil
    end

    context 'Feature mhv_medications_display_pending_meds=true"' do
      before do
        Flipper.enable_actor(:mhv_medications_display_pending_meds, current_user) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      end

      it 'responds to GET #index with pending meds included in list' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_prescriptions_w_pending_meds') do
          get '/my_health/v1/prescriptions?page=1&per_page=99'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list_paginated')
        expect(JSON.parse(response.body)['data']).to be_truthy

        pending_med = JSON.parse(response.body)['data'].find do |rx|
          rx['attributes']['prescription_source'] == 'PD'
        end

        expect(pending_med).to be_truthy
      end
    end

    context 'Feature mhv_medications_display_pending_meds=false"' do
      before do
        Flipper.disable(:mhv_medications_display_pending_meds) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      end

      it 'responds to GET #index with pending meds not included in list' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_prescriptions_w_pending_meds') do
          get '/my_health/v1/prescriptions?page=1&per_page=99'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list_paginated')
        expect(JSON.parse(response.body)['data']).to be_truthy

        pending_med = JSON.parse(response.body)['data'].find do |rx|
          rx['attributes']['prescription_source'] == 'PD'
        end

        expect(pending_med).to be_falsey
      end
    end

    context 'grouping medications' do
      it 'responds to GET #index by grouping medications and removes grouped medications from original list' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_paginated_list_of_grouped_prescriptions') do
          get '/my_health/v1/prescriptions?page=1&per_page=20'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list_paginated')
        expect(JSON.parse(response.body)['data']).to be_truthy

        grouped_med_list = JSON.parse(response.body)['data']
        first_rx = grouped_med_list.find do |rx|
          rx['attributes']['grouped_medications'].present?
        end
        rx_num_of_grouped_rx = first_rx['attributes']['grouped_medications'].first['prescription_number']
        find_grouped_rx_in_base_list = grouped_med_list.find do |rx|
          rx['attributes']['prescription_number'] == rx_num_of_grouped_rx
        end
        expect(find_grouped_rx_in_base_list).to be_falsey
      end

      it 'responds to GET #show with a single grouped medication' do
        prescription_id = '24891624'
        VCR.use_cassette('rx_client/prescriptions/gets_a_single_grouped_prescription') do
          get "/my_health/v1/prescriptions/#{prescription_id}"
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/prescriptions/v1/prescription_single')
        data = JSON.parse(response.body)['data']
        expect(data).to be_truthy
        expect(data['attributes']['prescription_id']).to eq(prescription_id.to_i)
      end

      it 'responds to GET #show with record not found when prescription_id is a part of a grouped medication' do
        prescription_id = '22565799'
        VCR.use_cassette('rx_client/prescriptions/gets_grouped_med_record_not_found') do
          get "/my_health/v1/prescriptions/#{prescription_id}"
        end

        errors = JSON.parse(response.body)['errors'][0]
        expect(errors).to be_truthy
        expect(errors['detail']).to eq("The record identified by #{prescription_id} could not be found")
      end
    end

    it 'responds to GET #get_prescription_image with image' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_prescription_image_v1') do
        get '/my_health/v1/prescriptions?/prescriptions/get_prescription_image/00013264681'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list')
      expect(JSON.parse(response.body)['data']).to be_truthy
    end

    it 'responds to GET #index with pagination parameters' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_paginated_list_of_prescriptions') do
        get '/my_health/v1/prescriptions?page=1&per_page=10'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list_paginated')
      expect(JSON.parse(response.body)['meta']['pagination']['current_page']).to eq(1)
      expect(JSON.parse(response.body)['meta']['pagination']['per_page']).to eq(10)
    end

    it 'responds to GET #list_refillable_prescriptions with list of refillable prescriptions' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_refillable_prescriptions') do
        get '/my_health/v1/prescriptions/list_refillable_prescriptions'
      end
      response_data = JSON.parse(response.body)['data']

      response_data.each do |p|
        prescription = p['attributes']
        disp_status = prescription['disp_status']
        refill_history_item = prescription['rx_rf_records']&.first
        expired_date = if refill_history_item && refill_history_item['expiration_date']
                         refill_history_item['expiration_date']
                       else
                         prescription['expiration_date']
                       end
        cut_off_date = Time.zone.today - 120.days
        zero_date = Date.new(0, 1, 1)
        meets_criteria = ['Active', 'Active: Parked'].include?(disp_status) ||
                         (disp_status == 'Expired' &&
                          expired_date.present? &&
                          DateTime.parse(expired_date) != zero_date &&
                          DateTime.parse(expired_date) >= cut_off_date)
        expect(meets_criteria).to be(true)
      end
      recently_requested = JSON.parse(response.body)['meta']['recently_requested']
      expect(recently_requested).to be_an(Array)
      recently_requested.each do |prescription|
        expect(prescription['disp_status']).to(satisfy { |status| ['Active: Refill in Process', 'Active: Submitted'].include?(status) })
      end
    end

    it 'responds to GET #index with filter metadata for specific disp_status' do
      VCR.use_cassette('rx_client/prescriptions/index_with_disp_status_filter') do
        get '/my_health/v1/prescriptions?filter[[disp_status][eq]]=Active,Expired',
            headers: { 'Content-Type' => 'application/json' }, as: :json
      end
      expect(response).to be_successful
      json_response = JSON.parse(response.body)
      expect(json_response['meta']['filter_count']).to include(
        'all_medications', 'active', 'recently_requested', 'renewal', 'non_active'
      )
      expect(json_response['meta']['filter_count']['all_medications']).to be >= 0
      expect(json_response['meta']['filter_count']['active']).to be >= 0
      expect(json_response['meta']['filter_count']['recently_requested']).to be >= 0
      expect(json_response['meta']['filter_count']['renewal']).to be >= 0
      expect(json_response['meta']['filter_count']['non_active']).to be >= 0
      disp_statuses = json_response['data'].map { |prescription| prescription['attributes']['disp_status'] }
      expect(disp_statuses).to all(be_in(%w[Active Expired]))
    end

    it 'responds to GET #index with pagination parameters when camel-inflected' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_paginated_list_of_prescriptions') do
        get '/my_health/v1/prescriptions?page=2&per_page=20', headers: inflection_header
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('my_health/prescriptions/v1/prescriptions_list_paginated')
      expect(JSON.parse(response.body)['meta']['pagination']['currentPage']).to eq(2)
      expect(JSON.parse(response.body)['meta']['pagination']['perPage']).to eq(20)
    end

    it 'responds to GET #index with custom sort parameter alphabetical-rx-name' do
      VCR.use_cassette('rx_client/prescriptions/gets_sorted_list') do
        get '/my_health/v1/prescriptions?sort=alphabetical-rx-name'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list')
      response_data = JSON.parse(response.body)['data']
      objects = skip_pending_meds(response_data).map do |item|
        {
          'prescription_name' => item.dig('attributes', 'prescription_name'),
          'sorted_dispensed_date' => item.dig('attributes', 'sorted_dispensed_date') || Date.new(0).to_s
        }
      end
      # Expect alphabetical order of prescription names
      expect(objects.map { |o| o['prescription_name'] }).to eq(objects.map { |o| o['prescription_name'] }.sort)

      # If prescription is the same, verify sort is by newest sorted_dispensed_date to oldest
      objects.group_by { |o| o['prescription_name'] }.each_value do |meds|
        # Separate empty dates (Date.new(0)) and actual dates
        empty_dates, with_dates = meds.partition { |m| m['sorted_dispensed_date'] == Date.new(0).to_s }

        # Get dates from non-empty group and sort them newest to oldest
        sorted_dates = with_dates.map { |m| m['sorted_dispensed_date'] }.sort.reverse

        # Verify that actual dates match expected order (empty dates, then sorted dates)
        actual_dates = meds.map { |m| m['sorted_dispensed_date'] }
        expected_dates = empty_dates.map { |m| m['sorted_dispensed_date'] } + sorted_dates

        expect(actual_dates).to eq(expected_dates)
      end
    end

    it 'responds to GET #index with custom sort parameter last-fill-date with expected sort strategy' do
      VCR.use_cassette('rx_client/prescriptions/gets_sorted_list') do
        get '/my_health/v1/prescriptions?sort=last-fill-date'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list')
      response_data = JSON.parse(response.body)['data']
      objects = skip_pending_meds(response_data).map do |item|
        {
          'prescription_name' => item.dig('attributes', 'prescription_name'),
          'sorted_dispensed_date' => item.dig('attributes', 'sorted_dispensed_date') || Date.new(0).to_s,
          'prescription_source' => item.dig('attributes', 'prescription_source')
        }
      end

      last_filled_index = objects.rindex { |obj| obj['sorted_dispensed_date'].present? }
      last_va_med_index = objects.rindex { |obj| obj['prescription_source'] != 'NV' }

      if last_filled_index && last_va_med_index && last_filled_index < last_va_med_index
        meds_between_indices = objects[(last_filled_index + 1)..last_va_med_index]

        if meds_between_indices.any?
          # Verify alphabetical order of empty sorted dispensed date va meds
          sorted_meds_between_indices = meds_between_indices.sort_by { |med| med['prescription_name'].downcase }
          expect(meds_between_indices).to eq(sorted_meds_between_indices)
        end
      end

      if last_filled_index
        meds_after_last_dispensed_med = objects[(last_filled_index + 1)..]
        if last_va_med_index < objects.size - 1
          meds_after_last_non_nv_med = objects[(last_va_med_index + 1)..]
          # Verify alphabetical order of empty sorted dispensed date non va meds
          if meds_after_last_non_nv_med.any?
            sorted_meds_after_last_non_nv_med = meds_after_last_non_nv_med.sort_by { |med| med['prescription_name'].downcase }

            expect(meds_after_last_non_nv_med).to eq(sorted_meds_after_last_non_nv_med)
          end
          # Verify that there are no more va meds
          expect(meds_after_last_non_nv_med.all? { |obj| obj['prescription_source'] == 'NV' }).to be true
        end

        # Verify alphabetical order of empty non va meds
        expect(meds_after_last_dispensed_med).to be_empty
        expect(meds_after_last_dispensed_med.all? { |obj| obj['sorted_dispensed_date'].blank? }).to be true
      end

      objects.reject! { |obj| obj['sorted_dispensed_date'] == Date.new(0).to_s }
      # Verify that sorted dispensed date is in order of newest to oldest
      is_descending = objects.map { |obj| Date.parse(obj['sorted_dispensed_date']) }
      sort = is_descending.each_cons(2).all? { |a, b| a >= b }

      expect(sort).to be true
    end

    it 'responds to GET #index with default sort order when no sort params are present' do
      VCR.use_cassette('rx_client/prescriptions/gets_sorted_list') do
        get '/my_health/v1/prescriptions?page=1&per_page=99'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list_paginated')
      response_data = JSON.parse(response.body)['data']
      objects = skip_pending_meds(response_data).map do |item|
        {
          'prescription_name' => item.dig('attributes', 'prescription_name') || item.dig('attributes', 'orderable_item'),
          'disp_status' => item.dig('attributes', 'disp_status')
        }
      end
      expect(objects).to eq(objects.sort_by { |object| [object['disp_status'], object['prescription_name']] })
    end

    it 'responds to GET #index with refill_status=active' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions') do
        get '/my_health/v1/prescriptions?refill_status=active'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list')
      expect(JSON.parse(response.body)['meta']['sort']).to eq(
        'disp_status' => 'ASC',
        'prescription_name' => 'ASC',
        'dispensed_date' => 'DESC'
      )
    end

    it 'responds to GET #index with refill_status=active when camel-inflected' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions_v1') do
        get '/my_health/v1/prescriptions?refill_status=active', headers: inflection_header
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('my_health/prescriptions/v1/prescriptions_list')
      expect(JSON.parse(response.body)['meta']['sort']).to eq(
        'dispStatus' => 'ASC',
        'prescriptionName' => 'ASC',
        'dispensedDate' => 'DESC'
      )
    end

    it 'responds to GET #index with filter' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_filtered_v1') do
        get '/my_health/v1/prescriptions?filter[[refill_status][eq]]=refillinprocess'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescription_list_filtered')
    end

    it 'responds to GET #index with filter when camel-inflected' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_filtered_v1') do
        get '/my_health/v1/prescriptions?filter[[refill_status][eq]]=refillinprocess', headers: inflection_header
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('my_health/prescriptions/v1/prescription_list_filtered')
    end

    it 'responds to GET #index with filter and pagination' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_vagov') do
        get '/my_health/v1/prescriptions?page=1&per_page=100&filter[[disp_status][eq]]=Active: Refill in Process',
            headers: { 'Content-Type' => 'application/json' }, as: :json
      end

      filtered_response = JSON.parse(response.body)['data'].select do |i|
        i['attributes']['disp_status'] == 'Active: Refill in Process'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/prescriptions/v1/prescription_list_filtered_with_pagination')
      expect(filtered_response.length).to eq(JSON.parse(response.body)['data'].length)
      expect(filtered_response.length).to eq(JSON.parse(response.body)['meta']['pagination']['total_entries'])
    end

    it 'responds to POST #refill' do
      allow(UniqueUserEvents).to receive(:log_event)

      VCR.use_cassette('rx_client/prescriptions/refills_a_prescription') do
        patch '/my_health/v1/prescriptions/25567989/refill'
      end

      expect(response).to be_successful
      expect(response.body).to be_empty

      # Verify event logging was called
      expect(UniqueUserEvents).to have_received(:log_event).with(
        user: anything,
        event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED
      )
    end

    it 'responds to PATCH #refill_prescriptions' do
      allow(UniqueUserEvents).to receive(:log_event)

      VCR.use_cassette('rx_client/prescriptions/refills_multiple_prescriptions') do
        patch '/my_health/v1/prescriptions/refill_prescriptions', params: { ids: %w[25567989 25567990] }
      end

      expect(response).to be_successful
      response_body = JSON.parse(response.body)
      expect(response_body).to have_key('successful_ids')
      expect(response_body).to have_key('failed_ids')

      # Verify event logging was called
      expect(UniqueUserEvents).to have_received(:log_event).with(
        user: anything,
        event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED
      )
    end

    context 'prescription documentation' do
      it 'responds to GET #index of prescription documentation' do
        VCR.use_cassette('rx_client/prescriptions/gets_rx_documentation') do
          get '/my_health/v1/prescriptions/21296515/documentation'
        end
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        attrs = JSON.parse(response.body)['data']['attributes']
        expect(attrs['html']).to include('<h1>Somatropin</h1>')
      end

      it 'returns error when prescription is not found' do
        allow_any_instance_of(Rx::Client).to receive(:get_rx_details).and_return(nil)

        get '/my_health/v1/prescriptions/99999999/documentation'

        expect(response).to have_http_status(:not_found)
        error = JSON.parse(response.body)
        expect(error).to include('errors')
      end

      it 'returns error when NDC number is missing' do
        allow_any_instance_of(Rx::Client).to receive(:get_rx_details).and_return(
          double('Rx', cmop_ndc_value: nil)
        )

        get '/my_health/v1/prescriptions/13650541/documentation'

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)
        expect(error).to include('errors')
      end

      it 'returns 503 when upstream service fails' do
        allow_any_instance_of(Rx::Client).to receive(:get_rx_details).and_return(
          double('Rx', cmop_ndc_value: '00378-6155-10')
        )
        allow_any_instance_of(Rx::Client).to receive(:get_rx_documentation)
          .and_raise(Common::Client::Errors::ClientError.new('Service unavailable', 503))

        get '/my_health/v1/prescriptions/21296515/documentation'

        expect(response).to have_http_status(:service_unavailable)
      end

      it 'returns 503 when connection fails' do
        allow_any_instance_of(Rx::Client).to receive(:get_rx_details).and_return(
          double('Rx', cmop_ndc_value: '00378-6155-10')
        )
        allow_any_instance_of(Rx::Client).to receive(:get_rx_documentation)
          .and_raise(Common::Client::Errors::ClientError.new('Connection failed', 503))

        get '/my_health/v1/prescriptions/21296515/documentation'

        expect(response).to have_http_status(:service_unavailable)
      end

      it 'returns 503 when client error occurs' do
        allow_any_instance_of(Rx::Client).to receive(:get_rx_details).and_return(
          double('Rx', cmop_ndc_value: '00378-6155-10')
        )
        allow_any_instance_of(Rx::Client).to receive(:get_rx_documentation)
          .and_raise(Common::Client::Errors::ClientError.new('Bad request', 400))

        get '/my_health/v1/prescriptions/21296515/documentation'

        expect(response).to have_http_status(:service_unavailable)
      end
    end

    context 'nested resources' do
      it 'responds to GET #show of nested tracking resource' do
        VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_a_list_of_tracking_history_for_a_prescription') do
          get '/my_health/v1/prescriptions/13650541/trackings'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('trackings')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('shipped_date' => 'DESC')
      end

      it 'responds to GET #show of nested tracking resource when camel-inflected' do
        VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_a_list_of_tracking_history_for_a_prescription') do
          get '/my_health/v1/prescriptions/13650541/trackings',
              headers: inflection_header.merge('Content-Type' => 'application/json'), as: :json
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('trackings')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('shippedDate' => 'DESC')
      end

      it 'responds to GET #show of nested tracking resource with a shipment having no other prescriptions' do
        VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_tracking_with_empty_other_prescriptions') do
          get '/my_health/v1/prescriptions/13650541/trackings'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('trackings')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('shipped_date' => 'DESC')
      end

      it 'responds to GET #show of nested tracking resource with a shipment having no other prescriptions when camel-inflected' do
        VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_tracking_with_empty_other_prescriptions') do
          get '/my_health/v1/prescriptions/13650541/trackings', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('trackings')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('shippedDate' => 'DESC')
      end
    end

    context 'preferences' do
      it 'responds to GET #show of preferences' do
        VCR.use_cassette('rx_client/preferences/gets_rx_preferences') do
          get '/my_health/v1/prescriptions/preferences'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        attrs = JSON.parse(response.body)['data']['attributes']
        expect(attrs['email_address']).to eq('Praneeth.Gaganapally@va.gov')
        expect(attrs['rx_flag']).to be true
      end

      it 'responds to PUT #update of preferences' do
        VCR.use_cassette('rx_client/preferences/sets_rx_preferences', record: :none) do
          params = { email_address: 'kamyar.karshenas@va.gov',
                     rx_flag: false }
          put '/my_health/v1/prescriptions/preferences', params:
        end

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['id'])
          .to eq('59623c5f11b874409315b05a254a7ace5f6a1b12a21334f7b3ceebe1f1854948')
        expect(JSON.parse(response.body)['data']['attributes'])
          .to eq('email_address' => 'kamyar.karshenas@va.gov', 'rx_flag' => false)
      end

      it 'requires all parameters for update' do
        VCR.use_cassette('rx_client/preferences/sets_rx_preferences', record: :none) do
          params = { email_address: 'kamyar.karshenas@va.gov' }
          put '/my_health/v1/prescriptions/preferences', params:
        end

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns a custom exception mapped from i18n when email contains spaces' do
        VCR.use_cassette('rx_client/preferences/raises_a_backend_service_exception_when_email_includes_spaces') do
          params = { email_address: 'kamyar karshenas@va.gov',
                     rx_flag: false }
          put '/my_health/v1/prescriptions/preferences', params:
        end

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors'].first['code']).to eq('RX157')
      end

      it 'includes prescription description fields' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_single_grouped_prescription') do
          get '/my_health/v1/prescriptions/24891624'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/prescriptions/v1/prescription_single')

        response_data = JSON.parse(response.body)['data']
        prescription_attributes = response_data['attributes']

        expect(prescription_attributes).to include('shape')
        expect(prescription_attributes).to include('color')
        expect(prescription_attributes).to include('back_imprint')
        expect(prescription_attributes).to include('front_imprint')
      end
    end
  end
end
# rubocop:enable Layout/LineLength
