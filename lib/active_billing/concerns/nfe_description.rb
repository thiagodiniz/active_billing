module ActiveBilling
  module Concerns
    module NfeDescription
      extend ActiveSupport::Concern

      def nfe_resource_description
        nfe_description_template.presence || default_nfe_description
      end

      def nfe_description_template
        return resource.nfe_description if resource.respond_to?(:nfe_description)

        billing_entity = resource.send(ActiveBilling.configuration.billing_entity_method)
        return billing_entity.nfe_description if billing_entity.respond_to?(:bundle_billing) && billing_entity.bundle_billing

        resource.config.nfe_description if resource.respond_to?(:config)
      end

      def default_nfe_description
        I18n.t('active_billing.invoice.nfe_usage_description',
               default: 'Monthly subscription and usage charges')
      end
    end
  end
end
