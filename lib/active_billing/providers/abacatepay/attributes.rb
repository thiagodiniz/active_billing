module ActiveBilling
  module Providers
    class Abacatepay < Base
      # Builds the JSON bodies sent to AbacatePay from the local records.
      module Attributes
        PLAN_CYCLES = { "monthly" => "MONTHLY", "yearly" => "ANNUALLY" }.freeze

        CUSTOMER_FIELDS = { name: :name, email: :email, cellphone: :cellphone, taxId: :tax_id }.freeze

        private

        def customer_attributes(account)
          entity = account.billable_entity
          metadata = account.metadata || {}

          CUSTOMER_FIELDS.each_with_object({}) do |(api_key, method), attrs|
            value = entity.public_send(method) if entity.respond_to?(method)
            value ||= metadata[api_key.to_s] || metadata[method.to_s]
            attrs[api_key] = value.to_s if value.present?
          end
        end

        def product_attributes(plan)
          cycle = PLAN_CYCLES[plan.interval]
          raise Error, "#{provider_name}: unsupported plan interval #{plan.interval}" if cycle.nil?

          { externalId: plan.uuid, name: plan.name, price: plan.price_in_cents.cents, currency: "BRL", cycle: cycle }
        end

        def subscription_attributes(billing, account, plan_reference)
          {
            items: [{ id: plan_reference.external_id, quantity: 1 }],
            customerId: account.external_customer_id,
            externalId: billing.uuid,
            methods: Array(setting(:subscription_methods).presence || ["CARD"]),
            metadata: { billing_uuid: billing.uuid },
            returnUrl: setting(:return_url),
            completionUrl: setting(:completion_url)
          }.compact
        end

        def payment_attributes(charge, account)
          invoice = charge.invoice

          {
            amount: invoice&.amount_in_cents&.cents,
            description: invoice&.description.presence || charge.create_description,
            externalId: charge.uuid,
            expiresIn: setting(:pix_expires_in),
            metadata: { charge_uuid: charge.uuid, invoice_uuid: invoice&.uuid }.compact,
            customer: payer_attributes(account)
          }.compact
        end

        # PIX payer data is optional, but when given AbacatePay requires every field.
        def payer_attributes(account)
          payer = customer_attributes(account)
          payer if CUSTOMER_FIELDS.keys.all? { |key| payer.key?(key) }
        end
      end
    end
  end
end
