# frozen_string_literal: true

require 'medical_records/bb_internal/client'

module MyHealth
  module V1
    module MedicalRecords
      class SelfEnteredController < ApplicationController
        include MyHealth::MHVControllerConcerns
        include MyHealth::AALClientConcerns
        include JsonApiPaginationLinks
        service_tag 'mhv-medical-records'

        MAX_PER_PAGE = 100

        def index
          resource = handle_aal('Self entered health information', 'Download', once_per_session: true) do
            data = client.get_all_sei_data

            # Apply pagination if requested
            if using_pagination?
              apply_pagination(data)
            else
              data
            end
          end
          render json: resource
        end

        def vitals
          render json: client.get_sei_vital_signs_summary.to_json
        end

        def allergies
          render json: client.get_sei_allergies.to_json
        end

        def family_history
          render json: client.get_sei_family_health_history.to_json
        end

        def vaccines
          render json: client.get_sei_immunizations.to_json
        end

        def test_entries
          render json: client.get_sei_test_entries.to_json
        end

        def medical_events
          render json: client.get_sei_medical_events.to_json
        end

        def military_history
          render json: client.get_sei_military_history.to_json
        end

        def providers
          render json: client.get_sei_healthcare_providers.to_json
        end

        def health_insurance
          render json: client.get_sei_health_insurance.to_json
        end

        def treatment_facilities
          render json: client.get_sei_treatment_facilities.to_json
        end

        def food_journal
          render json: client.get_sei_food_journal.to_json
        end

        def activity_journal
          render json: client.get_sei_activity_journal.to_json
        end

        def medications
          render json: client.get_sei_medications.to_json
        end

        def emergency_contacts
          render json: client.get_sei_emergency_contacts.to_json
        end

        protected

        def client
          @client ||= BBInternal::Client.new(session: { user_id: current_user.mhv_correlation_id })
        end

        def authorize
          raise_access_denied if current_user.mhv_correlation_id.blank? || current_user.icn.blank?
        end

        def raise_access_denied
          raise Common::Exceptions::Forbidden, detail: 'You do not have access to self-entered information'
        end

        def product
          :mr
        end

        private

        def using_pagination?
          params[:page].present? || params[:per_page].present?
        end

        def apply_pagination(data)
          # Flatten all category data into a single array for pagination
          all_items = flatten_category_data(data[:responses])

          page = [params[:page].to_i, 1].max
          per_page = calculate_per_page

          paginated_items = paginate_items(all_items, page, per_page)
          paginated_responses = group_by_category(paginated_items)

          build_paginated_response(data[:errors], paginated_responses, page, per_page, all_items.length)
        end

        def calculate_per_page
          # Handle per_page: default to 20 if not provided, cap at MAX_PER_PAGE
          params[:per_page].present? ? [[params[:per_page].to_i, MAX_PER_PAGE].min, 1].max : 20
        end

        def paginate_items(all_items, page, per_page)
          start_index = (page - 1) * per_page
          end_index = start_index + per_page - 1
          all_items[start_index..end_index] || []
        end

        def build_paginated_response(errors, responses, page, per_page, total_items)
          {
            responses:,
            errors:,
            pagination: {
              current_page: page,
              per_page:,
              total_entries: total_items,
              total_pages: (total_items.to_f / per_page).ceil
            }
          }
        end

        def flatten_category_data(responses)
          items = []
          responses.each do |category, category_data|
            next if category_data.blank?

            # Handle different data structures
            if category_data.is_a?(Array)
              category_data.each { |item| items << { category:, data: item } }
            elsif category_data.is_a?(Hash)
              # For nested structures, try to extract arrays
              extract_items_from_hash(category_data, category, items)
            else
              items << { category:, data: category_data }
            end
          end
          items
        end

        def extract_items_from_hash(hash, category, items)
          # Check for common array keys in the hash
          array_keys = hash.keys.select { |k| hash[k].is_a?(Array) }

          if array_keys.any?
            array_keys.each do |key|
              hash[key].each { |item| items << { category:, data: item } }
            end
          else
            items << { category:, data: hash }
          end
        end

        def group_by_category(items)
          grouped = {}
          items.each do |item|
            category = item[:category]
            grouped[category] ||= []
            grouped[category] << item[:data]
          end
          grouped
        end
      end
    end
  end
end
