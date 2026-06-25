module ActiveBilling
  class Engine < ::Rails::Engine
    isolate_namespace ActiveBilling

    # Models live under lib/active_billing/models and are namespaced ActiveBilling::*.
    # Register that directory with the app's main autoloader so the model classes
    # load lazily (after ActiveRecord is available) and reload in development.
    initializer "active_billing.autoload_models" do
      models_path = ActiveBilling::Engine.root.join("lib", "active_billing", "models")
      Rails.autoloaders.main.push_dir(models_path.to_s, namespace: ActiveBilling)
    end

    # Register the custom money attribute type. Runs during boot, after the
    # ActiveRecord railtie has loaded, so ActiveRecord::Type is available.
    initializer "active_billing.money_type" do
      require "active_billing/type/money"
      ActiveRecord::Type.register(:active_billing_money, ActiveBilling::Type::Money)
    end
  end
end
