# frozen_string_literal: true

module IvcChampva
    module ProdSupportUtilities
        class MissingStatusCleanup
            # TODO: can we combine this with IvcChampva::ProdSupportUtilities::Insights::get_user_batches_in_window ?
            # Or does this function belong in `Insights` class?
            def get_statuses
                all_nil_statuses = IvcChampvaForm.where(pega_status: nil)
            
                batches = {}
            
                # Group all nil results into batches by form UUID
                all_nil_statuses.map {|el| 
                    batch = IvcChampvaForm.where(form_uuid: el.form_uuid)
                    batches[el.form_uuid] = batch
                }
            
                # Print out details of each batch that contains a missing PEGA status:
                batches.each {|batch_id, batch|
                    nil_in_batch = batch.where(pega_status: nil)
                    el = nil_in_batch[0]
                    puts "---"
                    puts "#{el.first_name} #{el.last_name} missing PEGA status on #{nil_in_batch.length}/#{batch.length} attachments - #{el.email}\n"
                    puts "Form UUID:   #{el.form_uuid}"
                    puts "Uploaded at: #{el.created_at}"
                    puts "S3 Status:   #{nil_in_batch.distinct.pluck(:s3_status)}\n"
                }
                batches
            end

            # TODO: Condense functionality - this method is way too similar to the above
            def get_batches_for_email(email_addr)
                results= IvcChampvaForm.where(email: email_addr)
            
                batches = {}
            
                # Group all results into batches by form UUID
                results.map {|el| 
                    batch = IvcChampvaForm.where(form_uuid: el.form_uuid)
                    batches[el.form_uuid] = batch
                }
            
                # Print out details of each batch:
                batches.each {|batch_id, batch|
                    nil_in_batch = batch.where(pega_status: nil)
                    el = batch[0] #nil_in_batch[0]
                    puts "---"
                    puts "#{el.first_name} #{el.last_name} missing PEGA status on #{nil_in_batch.length}/#{batch.length} attachments - #{el.email}\n"
                    puts "Form UUID:   #{el.form_uuid}"
                    puts "Form:   #{el.form_number}"
                    puts "Uploaded at: #{el.created_at}"
                    puts "S3 Status:   #{batch.distinct.pluck(:s3_status)}\n"
                }
                batches
            end
        end
    end
end
