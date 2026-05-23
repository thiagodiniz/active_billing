module ActiveBilling
  module Concerns
    module TimestampStoreAccessor
      extend ActiveSupport::Concern

      class_methods do
        def email_timestamp_store_accessors(*prefixes)
          prefixes.each do |prefix|
            store_accessor :email_timestamps,
                          :"#{prefix}_email_sent_at",
                          :"#{prefix}_email_opened_at",
                          :"#{prefix}_email_clicked_at"

            %w[sent opened clicked].each do |action|
              define_method("#{prefix}_email_#{action}?") do
                send("#{prefix}_email_#{action}_at").present?
              end
            end
          end
        end
      end
    end
  end
end
