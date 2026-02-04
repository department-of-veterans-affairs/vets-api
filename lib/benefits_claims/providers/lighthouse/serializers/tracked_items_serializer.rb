# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module TrackedItemsSerializer
          def self.serialize(tracked_items)
            tracked_items.map { |item| serialize_item(item) }
          end

          def self.serialize_item(item)
            core_fields(item)
              .merge(date_fields(item))
              .merge(upload_fields(item))
              .merge(display_fields(item))
          end

          def self.core_fields(item)
            {
              'id' => item.id,
              'displayName' => item.display_name,
              'status' => item.status,
              'type' => item.type,
              'description' => item.description,
              'overdue' => item.overdue
            }
          end

          def self.date_fields(item)
            {
              'suspenseDate' => item.suspense_date,
              'closedDate' => item.closed_date,
              'receivedDate' => item.received_date,
              'requestedDate' => item.requested_date,
              'date' => item.date
            }
          end

          def self.upload_fields(item)
            {
              'uploadsAllowed' => item.uploads_allowed,
              'uploaded' => item.uploaded,
              'canUploadFile' => item.can_upload_file,
              'documents' => item.documents
            }
          end

          def self.display_fields(item)
            fields = {
              'friendlyName' => item.friendly_name,
              'friendlyDescription' => item.friendly_description,
              'activityDescription' => item.activity_description,
              'shortDescription' => item.short_description,
              'supportAliases' => item.support_aliases
            }
            # New content override fields (populated when cst_evidence_requests_content_override is enabled)
            add_content_field(fields, 'longDescription', item.long_description)
            add_content_field(fields, 'nextSteps', item.next_steps)
            add_content_field(fields, 'noActionNeeded', item.no_action_needed)
            add_content_field(fields, 'isDBQ', item.is_dbq)
            add_content_field(fields, 'isProperNoun', item.is_proper_noun)
            add_content_field(fields, 'isSensitive', item.is_sensitive)
            add_content_field(fields, 'noProvidePrefix', item.no_provide_prefix)

            fields
          end

          def self.add_content_field(fields, key, value)
            fields[key] = value unless value.nil?
          end
        end
      end
    end
  end
end
