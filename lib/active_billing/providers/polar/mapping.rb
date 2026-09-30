module ActiveBilling
  module Providers
    class Polar < Base
      # Builds Polar request bodies from local records and turns Polar payloads
      # into `Result`s.
      module Mapping
        private

        def currency
          ActiveBilling.configuration.currency.to_s.downcase
        end

        def customer_attributes(account)
          entity = account.billable_entity
          {
            email: entity.try(:email),
            name: entity.try(:name),
            external_id: "#{account.billable_entity_type}:#{account.billable_entity_id}",
            metadata: { "active_billing_account_uuid" => account.uuid.to_s }
          }.compact
        end

        def customer_raw(customer)
          customer.slice("id", "email", "name", "external_id")
        end

        def interval_for(plan)
          INTERVALS.fetch(plan.interval.to_s) { raise ArgumentError, "polar: unsupported interval #{plan.interval}" }
        end

        def product_attributes(plan)
          {
            name: plan.name,
            prices: [fixed_price(plan.price_in_cents&.cents || 0)],
            metadata: { "active_billing_plan_id" => plan.id.to_s }
          }
        end

        def fixed_price(amount_in_cents)
          { amount_type: "fixed", price_amount: amount_in_cents, price_currency: currency }
        end

        def product_result(product, status: nil)
          price = Array(product["prices"]).first || {}
          Result.new(external_id: product["id"], status: status || (product["is_archived"] ? "archived" : "active"),
                     raw: { "product_id" => product["id"], "price_id" => price["id"],
                            "recurring_interval" => product["recurring_interval"] })
        end

        def checkout_attributes(account)
          { customer_id: account&.external_customer_id, success_url: setting(:success_url) }.compact
        end

        def payment_checkout_attributes(charge, account, product_id)
          checkout_attributes(account).merge(
            products: [product_id],
            prices: { product_id => [fixed_price(charge_amount(charge))] },
            metadata: { "active_billing_charge_id" => charge.id.to_s, "active_billing_charge_uuid" => charge.uuid.to_s }
          )
        end

        def create_payment_product(charge)
          description = charge.invoice&.description.presence || charge.create_description
          client.post("/products", name: description.to_s.truncate(100),
                                   recurring_interval: nil,
                                   prices: [fixed_price(charge_amount(charge))],
                                   metadata: { "active_billing_charge_id" => charge.id.to_s })
        end

        def charge_amount(charge)
          charge.invoice&.amount_in_cents&.cents || 0
        end

        def fetch_checkout(checkout_id)
          client.get("/checkouts/#{checkout_id}")
        end

        def checkout_result(checkout, status: nil)
          Result.new(external_id: checkout["id"],
                     status: status || CHECKOUT_STATUSES.fetch(checkout["status"], "pending"),
                     url: checkout["url"],
                     raw: { "checkout_id" => checkout["id"], "checkout_status" => checkout["status"],
                            "subscription_id" => checkout["subscription_id"], "customer_id" => checkout["customer_id"],
                            "expires_at" => checkout["expires_at"] }.compact)
        end

        def subscription_id_for(reference)
          reference.metadata["subscription_id"].presence || fetch_checkout(reference.external_id)["subscription_id"]
        end

        def subscription_result(subscription, reference, status: nil)
          Result.new(external_id: reference.external_id, status: status || subscription["status"],
                     raw: { "subscription_id" => subscription["id"], "subscription_status" => subscription["status"],
                            "product_id" => subscription["product_id"],
                            "cancel_at_period_end" => subscription["cancel_at_period_end"],
                            "current_period_end" => subscription["current_period_end"] })
        end
      end
    end
  end
end
