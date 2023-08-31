# frozen_string_literal: true

module ApiPagination
  class Configuration
    attr_accessor :total_header, :per_page_header, :page_header, :include_total, :base_url, :response_formats

    def configure
      yield self
    end

    def initialize
      @total_header    = 'Total'
      @per_page_header = 'Per-Page'
      @page_header     = nil
      @include_total   = true
      @base_url = nil
      @response_formats = %i[json xml]
    end

    %w[page per_page].each do |param_name|
      method_name = "#{param_name}_param"
      instance_variable_name = "@#{method_name}"

      define_method method_name do |params = nil, &block|
        if block.is_a?(Proc)
          instance_variable_set(instance_variable_name, block)
          return
        end

        if instance_variable_get(instance_variable_name).nil?
          # use :page & :per_page by default
          instance_variable_set(instance_variable_name, (->(p) { p[param_name.to_sym] }))
        end

        instance_variable_get(instance_variable_name).call(params)
      end

      define_method "#{method_name}=" do |param|
        raise ArgumentError, 'Cannot set page_param option' unless param.is_a?(Symbol) || param.is_a?(String)

        instance_variable_set(instance_variable_name, (->(params) { params[param] }))
      end
    end

    def paginator
      if instance_variable_defined? :@paginator
        @paginator
      else
        set_paginator
      end
    end

    def paginator=(paginator)
      case paginator.to_sym
      when :pagy
        use_pagy
      when :kaminari
        use_kaminari
      when :will_paginate
        use_will_paginate
      else
        raise StandardError, "Unknown paginator: #{paginator}"
      end
    end

    private

    def set_paginator
      conditions = [defined?(Pagy), defined?(Kaminari), defined?(WillPaginate::CollectionMethods)]
      if conditions.compact.size > 1
        Kernel.warn <<~WARNING
          Warning: api-pagination relies on Pagy, Kaminari, or WillPaginate, but more than
          one are currently active. If possible, you should remove one or the other. If
          you can't, you _must_ configure api-pagination on your own. For example:

          ApiPagination.configure do |config|
            config.paginator = :kaminari
          end

          You should also configure Kaminari to use a different `per_page` method name as
          using these gems together causes a conflict; some information can be found at
          https://github.com/activeadmin/activeadmin/wiki/How-to-work-with-will_paginate

          Kaminari.configure do |config|
            config.page_method_name = :per_page_kaminari
          end

        WARNING
      elsif defined?(Pagy)
        use_pagy
      elsif defined?(Kaminari)
        use_kaminari
      elsif defined?(WillPaginate::CollectionMethods)
        use_will_paginate
      end
    end

    def use_pagy
      @paginator = :pagy
    end

    def use_kaminari
      require 'kaminari/models/array_extension'
      @paginator = :kaminari
    end

    def use_will_paginate
      WillPaginate::CollectionMethods.module_eval do
        def first_page?
          !previous_page
        end

        def last_page?
          !next_page
        end
      end

      @paginator = :will_paginate
    end
  end

  class << self
    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
    end
    alias configuration config
  end
end
