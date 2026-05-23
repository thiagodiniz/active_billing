module ActiveBilling
  module Concerns
    module CurrencyAttribute
      extend ActiveSupport::Concern

      class_methods do
        def currency_attrs(*attributes)
          attributes.each do |attribute|
            define_method("#{attribute}_in_cents") do
              self[:"#{attribute}_in_cents"]
            end

            define_method("#{attribute}_in_cents=") do |value|
              self[:"#{attribute}_in_cents"] = value
            end

            define_method(attribute) do
              value = send("#{attribute}_in_cents")
              value ? value / 100.0 : 0.0
            end

            define_method("#{attribute}=") do |value|
              send("#{attribute}_in_cents=", (value.to_f * 100).to_i)
            end
          end
        end
      end
    end
  end
end
