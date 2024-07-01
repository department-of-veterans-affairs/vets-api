# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Decision
      # Serialization is inherently linked to a particular BGS service action,
      # as it maps to the representation for that action. For now, since only
      # one such mapping is needed, we'll extract that functionality to showcase
      # it in isolation.
      module Dump
        class << self
          def perform(id, decision, xml, data_aliaz)
            xml[data_aliaz].POARequestUpdate do
              proc_id = id.split('_').last
              xml.procId(proc_id)

              xml.secondaryStatus(
                case decision.status
                when Statuses::ACCEPTING
                  'Accepted'
                when Statuses::DECLINING
                  'Declined'
                end
              )

              xml.declinedReason(decision.declining_reason)

              created_at = Utilities::Dump.time(decision.created_at)
              xml.dateRequestActioned(created_at)

              xml.VSOUserEmail(decision.created_by.email)
              xml.VSOUserFirstName(decision.created_by.first_name)
              xml.VSOUserLastName(decision.created_by.last_name)
            end
          end
        end
      end
    end
  end
end
