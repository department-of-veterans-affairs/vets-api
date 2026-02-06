# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Builders
        module TrackedItemsBuilder
          def self.build(tracked_items_data)
            return nil if tracked_items_data.nil?
            return [] if tracked_items_data.empty?

            tracked_items_data.map { |item_data| build_item(item_data) }
          end

          def self.build_item(item_data)
            BenefitsClaims::Responses::TrackedItem.new(
              **core_attributes(item_data),
              **date_attributes(item_data),
              **upload_attributes(item_data),
              **display_attributes(item_data)
            )
          end

          def self.core_attributes(data)
            {
              id: data['id'],
              display_name: data['displayName'],
              status: data['status'],
              type: data['type'],
              description: data['description'],
              overdue: data['overdue']
            }
          end

          def self.date_attributes(data)
            {
              suspense_date: data['suspenseDate'],
              closed_date: data['closedDate'],
              received_date: data['receivedDate'],
              requested_date: data['requestedDate'],
              date: data['date']
            }
          end

          def self.upload_attributes(data)
            {
              uploads_allowed: data['uploadsAllowed'],
              uploaded: data['uploaded'],
              can_upload_file: data['canUploadFile'],
              documents: data['documents']
            }
          end

          def self.display_attributes(data)
            {
              friendly_name: data['friendlyName'],
              friendly_description: data['friendlyDescription'],
              activity_description: data['activityDescription'],
              short_description: data['shortDescription'],
              # New content override fields (populated when cst_evidence_requests_content_override is enabled)
              support_aliases: data['supportAliases'],
              long_description: data['longDescription'],
              next_steps: data['nextSteps'],
              no_action_needed: data['noActionNeeded'],
              is_dbq: data['isDBQ'],
              is_proper_noun: data['isProperNoun'],
              is_sensitive: data['isSensitive'],
              no_provide_prefix: data['noProvidePrefix']
            }
          end
        end
      end
    end
  end
end
