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
                       mhv_account_type:,
                       sign_in: { service_name: SignIn::Constants::Auth::IDME })
  end
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    allow(Rx::Client).to receive(:new).and_return(authenticated_client)
    Flipper.enable(:mhv_medications_display_documentation_content)
    sign_in_as(current_user)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    before { get '/my_health/v1/prescriptions/13651310' }

    include_examples 'for user account level', message: 'You do not have access to prescriptions'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to prescriptions'
  end

  def skip_pending_meds(array)
    array.reject { |item| item['attributes']['prescription_source'] == 'PD' }
  end

  %w[Premium Advanced].each do |account_level|
    context "#{account_level} User" do
      let(:mhv_account_type) { account_level }

      context 'not a va patient' do
        before { get '/my_health/v1/prescriptions/13651310' }

        let(:va_patient) { false }
        let(:current_user) do
          build(:user,
                :mhv,
                :no_vha_facilities,
                authn_context: LOA::IDME_LOA3_VETS,
                va_patient:,
                mhv_account_type:,
                sign_in: { service_name: SignIn::Constants::Auth::IDME })
        end

        include_examples 'for non va patient user', authorized: false, message: 'You do not have access to prescriptions'
      end

      it 'responds to GET #show' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription_v1') do
          get '/my_health/v1/prescriptions/12284508'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/prescriptions/v1/prescription_single')
      end

      it 'responds to GET #show with camel-inlfection' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription_v1') do
          get '/my_health/v1/prescriptions/12284508', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('my_health/prescriptions/v1/prescription_single')
      end

      it 'responds to GET #index with no parameters' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/my_health/v1/prescriptions'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('prescription_name' => 'ASC')
      end

      it 'responds to GET #index with no parameters when camel-inflected' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/my_health/v1/prescriptions', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('my_health/prescriptions/v1/prescriptions_list')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('prescriptionName' => 'ASC')
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
          Flipper.enable_actor(:mhv_medications_display_pending_meds, current_user)
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
          Flipper.disable(:mhv_medications_display_pending_meds)
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
        before do
          Flipper.enable('mhv_medications_display_grouping')
        end

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

        Flipper.disable('mhv_medications_display_grouping')
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

      it 'responds to GET #index with prescription name as primary sort parameter' do
        VCR.use_cassette('rx_client/prescriptions/gets_sorted_list_by_prescription_name') do
          get '/my_health/v1/prescriptions?page=1&per_page=20&sort[]=prescription_name&sort[]=dispensed_date'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list_paginated')
        response_data = JSON.parse(response.body)['data']
        objects = skip_pending_meds(response_data).map do |item|
          {
            'prescription_name' => item.dig('attributes', 'prescription_name'),
            'sorted_dispensed_date' => item.dig('attributes', 'sorted_dispensed_date') || Date.new(0).to_s
          }
        end
        expect(objects).to eq(objects.sort_by { |object| [object['prescription_name'], object['sorted_dispensed_date']] })
      end

      it 'responds to GET #index with dispensed_date as primary sort parameter' do
        VCR.use_cassette('rx_client/prescriptions/gets_sorted_list_by_prescription_name') do
          get '/my_health/v1/prescriptions?page=1&per_page=20&sort[]=dispensed_date&sort[]=prescription_name'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/prescriptions/v1/prescriptions_list_paginated')
        response_data = JSON.parse(response.body)['data']
        objects = skip_pending_meds(response_data).map do |item|
          {
            'prescription_name' => item.dig('attributes', 'prescription_name'),
            'sorted_dispensed_date' => item.dig('attributes', 'sorted_dispensed_date') || Date.new(0).to_s
          }
        end
        expect(objects).to eq(objects.sort_by { |object| [object['sorted_dispensed_date'], object['prescription_name']] })
      end

      it 'responds to GET #index with disp_status as primary sort parameter' do
        VCR.use_cassette('rx_client/prescriptions/gets_sorted_list_by_prescription_name') do
          get '/my_health/v1/prescriptions?page=1&per_page=20&sort[]=disp_status&sort[]=prescription_name'
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
        expect(JSON.parse(response.body)['meta']['sort']).to eq('prescription_name' => 'ASC')
      end

      it 'responds to GET #index with refill_status=active when camel-inflected' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions_v1') do
          get '/my_health/v1/prescriptions?refill_status=active', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('my_health/prescriptions/v1/prescriptions_list')
        expect(JSON.parse(response.body)['meta']['sort']).to eq('prescriptionName' => 'ASC')
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
        VCR.use_cassette('rx_client/prescriptions/refills_a_prescription') do
          patch '/my_health/v1/prescriptions/13650545/refill'
        end

        expect(response).to be_successful
        expect(response.body).to be_empty
      end

      context 'prescription documentation' do
        it 'responds to GET #index of prescription documentation' do
          VCR.use_cassette('rx_client/prescriptions/gets_rx_documentation') do
            get '/my_health/v1/prescriptions/21296515/documentation'
          end
          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response.body).to be_a(String)
          attrs = JSON.parse(response.body)['data']['attributes']
          expect(attrs['html']).to include('<h1>Somatropin</h1>')
        end

        it 'responds with error when the API unable to find documentation for NDC' do
          VCR.use_cassette('rx_client/prescriptions/gets_rx_documentation') do
            get '/my_health/v1/prescriptions/13650541/documentation'
          end
          expect(response).to have_http_status(:service_unavailable)
          error = JSON.parse(response.body)['error']
          expect(error).to include('Unable to fetch documentation')
        end

        it 'responds with not_found when the feature is disabled' do
          Flipper.disable(:mhv_medications_display_documentation_content)
          VCR.use_cassette('rx_client/prescriptions/gets_rx_documentation') do
            get '/my_health/v1/prescriptions/21296515/documentation'
          end
          expect(response).to have_http_status(:not_found)
          expect(JSON.parse(response.body)).to eq({ 'error' => 'Documentation is not available' })
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

        it 'responds to GET #index with sorted_dispensed_date' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_sorted_by_custom_field_list_of_all_prescriptions_v1') do
            get '/my_health/v1/prescriptions?sort[]=-dispensed_date&sort[]=prescription_name', headers: inflection_header
          end

          res = JSON.parse(response.body)
          dates = res['data'].map do |d|
            sorted_date_str = d.dig('attributes', 'sortedDispensedDate')
            Time.zone.parse(sorted_date_str) unless sorted_date_str.nil?
          end
          is_sorted = dates.compact_blank.each_cons(2).all? { |item1, item2| item1 >= item2 }
          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(is_sorted).to be_truthy
          expect(response).to match_camelized_response_schema('my_health/prescriptions/v1/prescriptions_list')

          metadata = {'dispensedDate' => 'DESC', 'prescriptionName' => 'ASC'}
          expect(JSON.parse(response.body)['meta']['sort']).to eq(metadata)
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
          VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription_v1') do
            get '/my_health/v1/prescriptions/12284508'
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
end
# rubocop:enable Layout/LineLength
