module ActiveBilling
  module Concerns
    module NfeDescription
      extend ActiveSupport::Concern

      def nfe_resource_description
        description_template.presence || default_nfe_description
      end

      def description_template
        configured_description_template || resource_description_template
      end

      def default_nfe_description
        I18n.t("active_billing.invoice.nfe_usage_description",
               default: "Monthly subscription and usage charges")
      end

      private

      # `config.invoice_description` receives the record and returns a format string
      # accepting %{month} and %{uuids}.
      def configured_description_template
        template = ActiveBilling.configuration.invoice_description
        return if template.nil?

        template.respond_to?(:call) ? template.call(self) : template
      end

      def resource_description_template
        return resource.nfe_description if resource.respond_to?(:nfe_description)

        entity = billing_entity_for(resource)
        return entity.nfe_description if entity.respond_to?(:nfe_description)

        resource.config.nfe_description if resource.respond_to?(:config)
      end

      def billing_entity_for(record)
        method = ActiveBilling.configuration.billing_entity_method
        record.public_send(method) if record.respond_to?(method)
      end
    end
  end
end
