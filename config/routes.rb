ActiveBilling::Engine.routes.draw do
  # Portal (read-only; every action is scoped by billable_entity_id).
  resources :invoices, only: %i[index show]
  resources :usages,   only: %i[index show]
  resources :charges,  only: %i[index show]

  # Current plan for the billable entity.
  resource :plan, only: %i[show]
end
