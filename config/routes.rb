ActiveBilling::Engine.routes.draw do
  # Portal (read-only; every action is scoped by billable_entity_id).
  resources :invoices, only: %i[index show]
  resources :usages,   only: %i[index show]
  resources :charges,  only: %i[index show]

  # Current plan for the billable entity.
  resource :plan, only: %i[show]

  # Payment-provider webhooks, e.g. POST /active_billing/webhooks/stripe.
  post "webhooks/:provider", to: "webhooks#create", as: :provider_webhooks
end
