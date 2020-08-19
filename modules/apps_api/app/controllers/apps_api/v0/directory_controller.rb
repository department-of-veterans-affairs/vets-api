# frozen_string_literal: true

#dependencies
require_dependency 'apps_api/application_controller'

module AppsApi
  module V0
    class DirectoryController < ApplicationController
      skip_before_action(:authenticate)

      # When this endpoint is hit, it sends a request to Okta to return all applications on our organization,
      # and filters out any that contain an ISO date in their label
      def index
        okta_service = Okta::Service.new
        filtered_apps = []

        # Hard coded url since BASE_URL in service is set to 'https://www.example.com'
        base_url = "https://deptva-eval.okta.com/api/v1/apps?limit=200&filter=status+eq+\"ACTIVE\""
        #url_list = []
        #url_list.concat(get_next_urls(okta_service))
        #puts url_list
        unfiltered_apps = recursively_get_apps(okta_service, base_url)
        puts "Total apps before filtering: #{unfiltered_apps.length}"

        # matches any ISO date.
        iso_pattern = /(\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\d\.\d+)|(\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\d)|(\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d)/
         
        # Iterate through the returned applications, and test for pattern matching, 
        # adding to our filtered apps array if pattern doesn't match
        unfiltered_apps.each do | app |
          unless app["label"] =~ iso_pattern
            filtered_apps << app
          end
        end

        puts "Total apps after filtering: #{filtered_apps.length}"

        render json: {
          data: filtered_apps
        }
      end
      
      # Get all links
      # For each link, spin up a thread to get apps
      # join apps
      
      def get_next_urls(okta_service)
        url_list = []
        app_response = okta_service.get_apps
        continue_to_next = contains_next(app_response.headers)

        while continue_to_next
          tmp_url = substring_next_link(app_response.headers)
          app_response = okta_service.get_apps(tmp_url)
          url_list << substring_next_link(app_response.headers)
          continue_to_next = contains_next(app_response.headers)
        end

        url_list
      end


      def recursively_get_apps(okta_service, url, unfiltered_apps=[])
        apps_response = okta_service.get_apps(url)
        
        # Moving apps in response body to iterable array
        unfiltered_apps.concat(apps_response.body)  

        # Check headers for ['link'] where 'rel' == next
        # If the next link exists, call okta_service.get_apps(next_link) and filter based on iso_pattern
        if contains_next(apps_response.headers)
          next_link = substring_next_link(apps_response.headers)
          puts next_link
          recursively_get_apps(okta_service, next_link, unfiltered_apps)
        end

        unfiltered_apps
      end

      # Check if headers contains 'next' link, since 'next' is always after 'self', we can use .last as a consistent check
      def contains_next(headers)
        headers['link'].split(',').last.include?("next") 
      end

      def substring_next_link(headers)
        headers['link'].split(',').last.split("<").last.split(">").first
      end

    end
  end
end
